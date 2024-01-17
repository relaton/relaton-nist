module RelatonNist
  class TechPubsParser
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

    ATTRS = %i[docid title link abstract date doctype edition contributor relation docstatus place series].freeze
    NS = "http://www.crossref.org/relations.xsd".freeze

    def initialize(doc, series)
      @doc = doc
      @series = series
    end

    #
    # Parse XML document
    #
    # @param doc [Nokogiri::XML::Element] XML document
    # @param series [Hash] series hash map (key: series abbreviation, value: series name)
    #
    # @return [RelatonNist::NistBibliographicItem] bibliographic item
    #
    def self.parse(doc, series)
      new(doc, series).parse
    end

    #
    # Create document instance
    #
    # @raise [StandardError]
    #
    # @return [RelatonNist::NistBibliographicItem] bibliographic item
    #
    def parse
      RelatonNist::NistBibliographicItem.new(
        type: "standard", language: [@doc["language"]], script: ["Latn"], **args
      )
    # rescue StandardError => e
    #   warn "Document: `#{pub_id}`"
    #   warn e.message
    #   warn e.backtrace[0..5].join("\n")
    end

    def args
      ATTRS.to_h { |a| [a, send("parse_#{a}")] }
    end

    # def anchor(doc)
    #   fetch_doi(doc).split("/")[1..-1].join "/"
    # end

    # @return [Array<RelatonBib::DocumentIdentifier>]
    def parse_docid
      [
        { type: "NIST", id: pub_id, primary: true },
        { type: "DOI", id: doi },
        # { type: "NIST", id: anchor(doc), scope: "anchor" },
      ].map { |id| RelatonBib::DocumentIdentifier.new(**id) }
    end

    #
    # Parse document's ID from XML
    #
    # @return [String] document's ID
    #
    def pub_id
      # anchor(doc).gsub(".", " ")
      if doi
        doi.split("/")[1..].join("/").gsub(".", " ").sub(/^nist\sir/, "NIST IR")
      else
        @doc.at("publisher_item/item_number").text
      end
    end

    def doi # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength
      return @doi if defined? @doi

      @doi = begin
        id = @doc.at("doi_data/doi")&.text
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
    end

    # @return [RelatonBib::TypedTitleStringCollection, Array]
    def parse_title
      t = @doc.xpath("titles/title|titles/subtitle")
      return [] unless t.any?

      # RelatonBib::TypedTitleString.from_string t.map(&:text).join, "en", "Latn"
      [{ content: t.map(&:text).join("\n"), language: "en", script: "Latn",
         format: "text/plain" }]
    end

    # @return [Array<RelatonBib::TypedUri>]
    def parse_link
      pdf_url = @doc.at("doi_data/resource").text
      doi_url = "https://doi.org/#{doi}"
      [{ type: "doi", content: doi_url }, { type: "pdf", content: pdf_url }]
        .map { |l| RelatonBib::TypedUri.new(**l) }
    end

    # @return [Array<RelatonBib::FormattedString>]
    def parse_abstract
      @doc.xpath(
        "jats:abstract/jats:p", "jats" => "http://www.ncbi.nlm.nih.gov/JATS1"
      ).each_with_object([]) do |a, m|
        next if a.text.empty?

        m << RelatonBib::FormattedString.new(content: a.text, language: @doc["language"], script: "Latn")
      end
    end

    # @return [Array<RelatonBib::BibliographicDate>]
    def parse_date
      @doc.xpath("publication_date|approval_date").map do |dt|
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

    def parse_doctype
      RelatonBib::DocumentType.new(type: "standard")
    end

    # @return [String]
    def parse_edition
      @doc.at("edition_number")&.text
    end

    # @return [Array<Hash>]
    def parse_contributor
      contribs = @doc.xpath("contributors/person_name").map do |p|
        person = RelatonBib::Person.new(name: fullname(p), affiliation: affiliation, identifier: identifier(p))
        { entity: person, role: [{ type: p["contributor_role"] }] }
      end
      contribs + @doc.xpath("publisher").map do |p|
        { entity: create_org(p), role: [{ type: "publisher" }] }
      end
    end

    def identifier(person)
      person.xpath("ORCID").map do |id|
        RelatonBib::PersonIdentifier.new "orcid", id.text
      end
    end

    #
    # Create full name object from person name element.
    #
    # @param [Nokogiri::XML::Element] person name element
    #
    # @return [RelatonBib::FullName] full name object
    #
    def fullname(person)
      fname, initials = forename_initial person
      surname = localized_string person.at("surname")&.text
      completename = localized_string person.text unless surname
      RelatonBib::FullName.new(
        surname: surname, forename: fname, initials: initials, completename: completename,
      )
    end

    #
    # Create affiliation organization
    #
    # @return [Array<RelatonBib::Affiliation>] affiliation
    #
    def affiliation
      @doc.xpath("./institution/institution_department").map do |id|
        org = RelatonBib::Organization.new name: id.text
        RelatonBib::Affiliation.new organization: org
      end
    end

    #
    # Create forename and initials objects from person name element.
    #
    # @param [Nokogiri::XML::Element] person person name element
    #
    # @return [Array<RelatonBib::Forename>, RelatonBib::LocalizedString>] forename and initialsrray<
    #
    def forename_initial(person) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      fnames = []
      fname = person.at("given_name")&.text
      if fname
        if /^(?:(?<name>\w+)\s)?(?<inits>(?:\w(?:\.|\b)\s?)+)/ =~ fname
          ints = inits.split(/[.\s]*/)
          fnames << forename(name, ints.shift)
          ints.each { |i| fnames << forename(nil, i) }
        else
          fn = forename(fname)
          fnames << fn if fn
        end
      end
      initials = localized_string inits unless inits.nil? || inits.empty?
      [fnames, initials]
    end

    #
    # Create forename object
    #
    # @param [String, nil] cnt forename content
    # @param [String, nil] init initial content
    #
    # @return [RelatonBib::Forename] forename object
    #
    def forename(cnt, init = nil)
      return if (cnt.nil? || cnt.empty?) && (init.nil? || init.empty?)

      RelatonBib::Forename.new(
        content: cnt, language: @doc["language"], script: "Latn", initial: init,
      )
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

    # @return [Array<Hash>]
    def parse_relation # rubocop:disable Metrics/AbcSize
      @doc.xpath("./ns:program/ns:related_item", ns: NS).map do |rel|
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

    def parse_docstatus
      s = @doc.at("./ns:program/ns:related_item/ns:*[@relationship-type='isPreprintOf']", ns: NS)
      return unless s

      RelatonBib::DocumentStatus.new stage: "preprint"
    end

    # @return [Array<String>]
    def parse_place
      @doc.xpath("institution/institution_place").map(&:text)
    end

    #
    # Fetches series
    #
    # @return [Array<RelatonBib::Series>] series
    #
    def parse_series
      prf, srs, num = pub_id.split
      sname = @series[srs] || srs
      title = RelatonBib::TypedTitleString.new(content: "#{prf} #{sname}")
      abbr = RelatonBib::LocalizedString.new srs
      [RelatonBib::Series.new(title: title, abbreviation: abbr, number: num)]
    end

    #
    # Create localized string
    #
    # @param [String] content content of string
    #
    # @return [RelatonBib::LocalizedString] localized string
    #
    def localized_string(content)
      return unless content
      RelatonBib::LocalizedString.new content, @doc["language"], "Latn"
    end
  end
end
