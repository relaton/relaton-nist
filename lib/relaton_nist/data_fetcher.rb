# frozen_string_literal: true

require "yaml"

module RelatonNist
  class DataFetcher
    RELATION_TYPES = {
      "replaces" => "obsoletes",
      "isVersionOf" => "editionOf",
      "hasTranslation" => "hasTranslation",
      "isTranslationOf" => "translatedFrom",
      "hasPreprint" => "hasReprint",
      "isPreprintOf" => "hasDraft",
      "isSupplementTo" => "complements",
      "isPartOf" => "partOf",
      "hasPart" => "hasPart",
    }.freeze

    URL = "https://raw.githubusercontent.com/usnistgov/NIST-Tech-Pubs/nist-pages/xml/allrecords.xml"
    NS = "http://www.crossref.org/relations.xsd"

    def initialize(output, format)
      @output = output
      @format = format
      @ext = format.sub(/^bib/, "")
      @files = []
    end

    def index
      @index ||= Relaton::Index.find_or_create :nist, file: "index-v1.yaml"
    end

    def parse_docid(doc) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      [
        { type: "NIST", id: pub_id(doc), primary: true },
        { type: "DOI", id: fetch_doi(doc) },
        # { type: "NIST", id: anchor(doc), scope: "anchor" },
      ]
    end

    #
    # Parse document's ID from XML
    #
    # @param [Nokogiri::XML::Element] doc XML element
    #
    # @return [String] document's ID
    #
    def pub_id(doc)
      # anchor(doc).gsub(".", " ")
      fetch_doi(doc).split("/")[1..].join("/").gsub(".", " ").sub(/^nist\sir/, "NIST IR")
    end

    def fetch_doi(doc) # rubocop:disable Metrics/CyclomaticComplexity
      id = doc.at("doi_data/doi").text
      case id
      when "10.6028/NBS.CIRC.e2e" then "10.6028/NBS.CIRC.2e2"
      when "10.6028/NBS.CIRC.sup" then "10.6028/NBS.CIRC.24e7sup"
      when "10.6028/NBS.CIRC.supJun1925-Jun1926" then "10.6028/NBS.CIRC.24e7sup2"
      when "10.6028/NBS.CIRC.supJun1925-Jun1927" then "10.6028/NBS.CIRC.24e7sup3"
      when "10.6028/NBS.CIRC.24supJuly1922" then "10.6028/NBS.CIRC.24e6sup"
      when "10.6028/NBS.CIRC.24supJan1924" then "10.6028/NBS.CIRC.24e6sup2"
      else id
      end
    end

    # def anchor(doc)
    #   fetch_doi(doc).split("/")[1..-1].join "/"
    # end

    # @param doc [Nokogiri::XML::Element]
    # @return [Array<RelatonBib::DocumentIdentifier>]
    def fetch_docid(doc)
      parse_docid(doc).map do |id|
        RelatonBib::DocumentIdentifier.new(**id)
      end
    end

    # @param doc [Nokogiri::XML::Element]
    # @return [RelatonBib::TypedTitleStringCollection, Array]
    def fetch_title(doc)
      t = doc.xpath("titles/title|titles/subtitle")
      return [] unless t.any?

      # RelatonBib::TypedTitleString.from_string t.map(&:text).join, "en", "Latn"
      [{ content: t.map(&:text).join, language: "en", script: "Latn",
         format: "text/plain" }]
    end

    # @param doc [Nokogiri::XML::Element]
    # @return [Array<RelatonBib::BibliographicDate>]
    def fetch_date(doc)
      doc.xpath("publication_date|approval_date").map do |dt|
        on = dt.at("year").text
        if (m = dt.at "month")
          on += "-#{m.text}"
          d = dt.at "day"
          on += "-#{d.text}" if d
        end
        type = dt.name == "publication_date" ? "published" : "confirmed"
        RelatonBib::BibliographicDate.new(type: type, on: on)
      end
    end

    # @param doc [Nokogiri::XML::Element]
    # @return [String]
    def fetch_edition(doc)
      doc.at("edition_number")&.text
    end

    # @param doc [Nokogiri::XML::Element]
    # @return [Array<Hash>]
    def fetch_relation(doc) # rubocop:disable Metrics/AbcSize
      doc.xpath("./ns:program/ns:related_item", ns: NS).map do |rel|
        rdoi = rel.at_xpath("ns:intra_work_relation|ns:inter_work_relation", ns: NS)
        id = rdoi.text.split("/")[1..].join("/").gsub(".", " ")
        fref = RelatonBib::FormattedRef.new content: id
        docid = RelatonBib::DocumentIdentifier.new(type: "NIST", id: id, primary: true)
        bibitem = RelatonBib::BibliographicItem.new formattedref: fref, docid: [docid]
        type = RELATION_TYPES[rdoi["relationship-type"]]
        warn "Relation type #{rdoi['relationship-type']} not found" unless type
        { type: type, bibitem: bibitem }
      end
    end

    def fetch_status(doc)
      s = doc.at("./ns:program/ns:related_item/ns:*[@relationship-type='isPreprintOf']", ns: NS)
      return unless s

      RelatonBib::DocumentStatus.new stage: "preprint"
    end

    # @param doc [Nokogiri::XML::Element]
    # @return [Array<RelatonBib::TypedUri>]
    def fetch_link(doc)
      pdf = doc.at("doi_data/resource").text
      doi = "https://doi.org/#{fetch_doi(doc)}"
      [{ type: "doi", content: doi }, { type: "pdf", content: pdf }].map do |l|
        RelatonBib::TypedUri.new(**l)
      end
    end

    # @param doc [Nokogiri::XML::Element]
    # @return [Array<RelatonBib::FormattedString>]
    def fetch_abstract(doc)
      doc.xpath(
        "jats:abstract/jats:p", "jats" => "http://www.ncbi.nlm.nih.gov/JATS1"
      ).each_with_object([]) do |a, m|
        next if a.text.empty?

        m << RelatonBib::FormattedString.new(content: a.text, language: doc["language"], script: "Latn")
      end
    end

    # @param doc [Nokogiri::XML::Element]
    # @return [Array<Hash>]
    def fetch_contributor(doc)
      contribs = doc.xpath("contributors/person_name").map do |p|
        person = RelatonBib::Person.new(name: fullname(p, doc),
                                        affiliation: affiliation(doc))
        { entity: person, role: [{ type: p["contributor_role"] }] }
      end
      contribs + doc.xpath("publisher").map do |p|
        { entity: create_org(p), role: [{ type: "publisher" }] }
      end
    end

    #
    # Create full name object from person name element.
    #
    # @param [Nokogiri::XML::Element] person name element
    # @param [Nokogiri::XML::Element] doc document element
    #
    # @return [RelatonBib::FullName] full name object
    #
    def fullname(person, doc)
      forename, initials = forename_initial(person, doc)
      surname = localized_string person.at("surname").text, doc
      ident = person.xpath("ORCID").map do |id|
        RelatonBib::PersonIdentifier.new "orcid", id.text
      end
      RelatonBib::FullName.new(surname: surname, forename: forename,
                               initials: initials, identifier: ident)
    end

    #
    # Create forename and initials objects from person name element.
    #
    # @param [Nokogiri::XML::Element] person person name element
    # @param [Nokogiri::XML::Element] doc document element
    #
    # @return [Array<Array<RelatonBib::LocalizedString>>] forename and initials
    #
    def forename_initial(person, doc) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      fnames = []
      fname = person.at("given_name")&.text
      if fname
        if /^(?<inits>(?:\w[.\s]+|[A-Z]{1,2}$)+)$/ =~ fname
          ints = inits.split(/[.\s]*/)
          fnames << forename(doc, fname, ints.shift)
          ints.each { |i| fnames << forename(doc, nil, i) }
        else
          fn = forename(doc, fname)
          fnames << fn if fn
        end
      end
      initials = localized_string inits, doc if not(inits.nil? || inits.empty?)
      [fnames, initials]
    end

    #
    # Create forename object
    #
    # @param [Nokogiri::XML::Element] doc document element
    # @param [String, nil] cnt forename content
    # @param [String, nil] init initial content
    #
    # @return [RelatonBib::Forename] forename object
    #
    def forename(doc, cnt, init = nil)
      return if (cnt.nil? || cnt.empty?) && (init.nil? || init.empty?)

      RelatonBib::Forename.new(
        content: cnt, language: doc["language"], script: "Latn", initial: init,
      )
    end

    #
    # Create localized string
    #
    # @param [String] content content of string
    # @param [Nokogiri::XML::Elemrnt] doc XML element
    #
    # @return [RelatonBib::LocalizedString] localized string
    #
    def localized_string(content, doc)
      RelatonBib::LocalizedString.new content, doc["language"], "Latn"
    end

    #
    # Create publisher organization
    #
    # @param [Nokogiri::XML::Element] pub publisher element
    #
    # @return [RelatonBib::Organization] publisher organization
    #
    def create_org(pub)
      name = pub.at("publisher_name").text
      abbr = pub.at("../institution[institution_name[.='#{name}']]/institution_acronym")&.text
      place = pub.at("./publisher_place") ||
        pub.at("../institution[institution_name[.='#{name}']]/institution_place")
      cont = []
      if place
        city, state = place.text.split(", ")
        cont << RelatonBib::Address.new(street: [], city: city, state: state, country: "US")
      end
      RelatonBib::Organization.new name: name, abbreviation: abbr, contact: cont
    end

    #
    # Create affiliation organization
    #
    # @param [Nokogiri::XML::Element] doc affiliation element
    #
    # @return [Array<RelatonBib::Affiliation>] affiliation
    #
    def affiliation(doc)
      doc.xpath("./institution/institution_department").map do |id|
        org = RelatonBib::Organization.new name: id.text
        RelatonBib::Affiliation.new organization: org
      end
    end

    # @param doc [Nokogiri::XML::Element]
    # @return [Array<String>]
    def fetch_place(doc)
      doc.xpath("institution/institution_place").map(&:text)
    end

    #
    # Fetches series
    #
    # @param [Nokogiri::XML::Element] doc document element
    #
    # @return [Array<RelatonBib::Series>] series
    #
    def fetch_series(doc)
      prf, srs, num = pub_id(doc).split
      sname = series[srs] || srs
      title = RelatonBib::TypedTitleString.new(content: "#{prf} #{sname}")
      abbr = RelatonBib::LocalizedString.new srs
      [RelatonBib::Series.new(title: title, abbreviation: abbr, number: num)]
    end

    def series
      @series ||= YAML.load_file File.expand_path("series.yaml", __dir__)
    end

    #
    # Save document
    #
    # @param bib [RelatonNist::NistBibliographicItem]
    #
    def write_file(bib) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      id = bib.docidentifier[0].id.gsub(%r{[/\s:.]}, "_").upcase.sub(/^NIST_IR/, "NISTIR")
      file = File.join(@output, "#{id}.#{@ext}")
      if @files.include? file
        warn "File #{file} exists. Docid: #{bib.docidentifier[0].id}"
        # warn "Link: #{bib.link.detect { |l| l.type == 'src' }.content}"
      else @files << file
      end
      output = case @format
               when "yaml" then bib.to_hash.to_yaml
               when "xml" then bib.to_xml bibdata: true
               else bib.send "to_#{@format}"
               end
      index.add_or_update bib.docidentifier[0].id, file
      File.write file, output, encoding: "UTF-8"
    end

    #
    # Create a document instance an save it.
    #
    # @param doc [Nokogiri::XML::Element]
    #
    # @raise [StandardError]
    #
    def parse_doc(doc) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
      # mtd = doc.at('doi_record/report-paper/report-paper_metadata')
      item = RelatonNist::NistBibliographicItem.new(
        type: "standard", docid: fetch_docid(doc),
        title: fetch_title(doc), link: fetch_link(doc), abstract: fetch_abstract(doc),
        date: fetch_date(doc), edition: fetch_edition(doc),
        contributor: fetch_contributor(doc), relation: fetch_relation(doc),
        docstatus: fetch_status(doc), place: fetch_place(doc), series: fetch_series(doc),
        language: [doc["language"]], script: ["Latn"], doctype: "standard"
      )
      write_file item
    rescue StandardError => e
      warn "Document: #{doc.at('doi').text}"
      warn e.message
      warn e.backtrace[0..5].join("\n")
      # raise e
    end

    #
    # Fetch all the documnts from dataset
    #
    def fetch # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      t1 = Time.now
      puts "Started at: #{t1}"

      docs = Nokogiri::XML OpenURI.open_uri URL
      FileUtils.mkdir_p @output
      FileUtils.rm Dir[File.join(@output, "*.#{@ext}")]
      docs.xpath("/body/query/doi_record/report-paper/report-paper_metadata")
        .each { |doc| parse_doc doc }

      index.save
      t2 = Time.now
      puts "Stopped at: #{t2}"
      puts "Done in: #{(t2 - t1).round} sec."
    rescue StandardError => e
      warn e.message
      warn e.backtrace[0..5].join("\n")
    end

    #
    # Fetch all the documnts from dataset
    #
    # @param [String] output foldet name to save the documents
    # @param [String] format format to save the documents (yaml, xml, bibxml)
    #
    def self.fetch(output: "data", format: "yaml")
      new(output, format).fetch
    end
  end
end
