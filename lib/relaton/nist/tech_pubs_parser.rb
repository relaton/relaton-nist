module Relaton
  module Nist
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

      ATTRS = %i[docidentifier title source abstract date edition contributor
                 relation status place series].freeze
      NS = "http://www.crossref.org/relations.xsd".freeze

      def initialize(doc, series)
        @doc = doc
        @series = series
      end

      #
      # Parse XML document
      #
      # @param doc [Nokogiri::XML::Element] XML document
      # @param series [Hash] series hash map
      #
      # @return [Relaton::Nist::ItemData] bibliographic item
      #
      def self.parse(doc, series)
        new(doc, series).parse
      end

      #
      # Create document instance
      #
      # @return [Relaton::Nist::ItemData] bibliographic item
      #
      def parse
        ItemData.new(
          type: "standard", language: [@doc["language"]], script: ["Latn"],
          ext: Ext.new(doctype: parse_doctype), **args
        )
      end

      def args
        ATTRS.to_h { |a| [a, send("parse_#{a}")] }
      end

      # @return [Array<Bib::Docidentifier>]
      def parse_docidentifier
        [
          { type: "NIST", content: pub_id, primary: true },
          { type: "DOI", content: doi },
        ].map { |id| Bib::Docidentifier.new(**id) }
      end

      #
      # Parse document's ID from XML
      #
      # @return [String] document's ID
      #
      def pub_id
        if doi
          doi.split("/")[1..].join("/").gsub(".", " ").sub(/^[\D]+/, &:upcase)
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

      # @return [Array<Bib::Title>]
      def parse_title
        t = @doc.xpath("titles/title|titles/subtitle")
        return [] unless t.any?

        [Bib::Title.new(content: t.map(&:text).join("\n"), language: "en", script: "Latn")]
      end

      # @return [Array<Bib::Uri>]
      def parse_source
        pdf_url = @doc.at("doi_data/resource").text
        doi_url = "https://doi.org/#{doi}"
        [
          Bib::Uri.new(type: "doi", content: doi_url),
          Bib::Uri.new(type: "pdf", content: pdf_url),
        ]
      end

      # @return [Array<Bib::LocalizedMarkedUpString>]
      def parse_abstract
        @doc.xpath(
          "jats:abstract/jats:p", "jats" => "http://www.ncbi.nlm.nih.gov/JATS1"
        ).each_with_object([]) do |a, m|
          next if a.text.empty?

          m << Bib::Abstract.new(
            content: a.text, language: @doc["language"], script: "Latn",
          )
        end
      end

      # @return [Array<Bib::Date>]
      def parse_date
        @doc.xpath("publication_date|approval_date").map do |dt|
          on = dt.at("year").text
          if (m = dt.at "month")
            on += "-#{m.text}"
            d = dt.at "day"
            on += "-#{d.text}" if d
          end
          type = dt.name == "publication_date" ? "published" : "confirmed"
          Bib::Date.new(type: type, at: on)
        end
      end

      def parse_doctype
        Doctype.new(content: "standard")
      end

      # @return [String]
      def parse_edition
        @doc.at("edition_number")&.text
      end

      # @return [Array<Bib::Contributor>]
      def parse_contributor # rubocop:disable Metrics/AbcSize
        contribs = @doc.xpath("contributors/person_name").map do |p|
          person = Bib::Person.new(
            name: fullname(p), affiliation: affiliation, identifier: identifier(p),
          )
          Bib::Contributor.new(
            person: person,
            role: [Bib::Contributor::Role.new(type: p["contributor_role"])],
          )
        end
        contribs + @doc.xpath("publisher").map do |p|
          Bib::Contributor.new(
            organization: create_org(p),
            role: [Bib::Contributor::Role.new(type: "publisher")],
          )
        end
      end

      def identifier(person)
        person.xpath("ORCID").map do |id|
          Bib::Person::Identifier.new(type: "orcid", content: id.text)
        end
      end

      #
      # Create full name object from person name element.
      #
      # @param [Nokogiri::XML::Element] person name element
      #
      # @return [Bib::FullName] full name object
      #
      def fullname(person)
        fname, initials = forename_initial person
        surname = localized_string person.at("surname")&.text
        completename = localized_string person.text unless surname
        Bib::FullName.new(
          surname: surname, forename: fname, formatted_initials: initials,
          completename: completename,
        )
      end

      #
      # Create affiliation organization
      #
      # @return [Array<Bib::Affiliation>] affiliation
      #
      def affiliation
        @doc.xpath("./institution/institution_department").map do |id|
          org = Bib::Organization.new(
            name: [Bib::TypedLocalizedString.new(content: id.text)],
          )
          Bib::Affiliation.new(organization: org)
        end
      end

      #
      # Create forename and initials objects from person name element.
      #
      # @param [Nokogiri::XML::Element] person person name element
      #
      # @return [Array<Array<Bib::FullNameType::Forename>, Bib::LocalizedString>]
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
      # @return [Bib::FullNameType::Forename] forename object
      #
      def forename(cnt, init = nil)
        return if (cnt.nil? || cnt.empty?) && (init.nil? || init.empty?)

        Bib::FullNameType::Forename.new(
          content: cnt, language: @doc["language"], script: "Latn", initial: init,
        )
      end

      #
      # Create publisher organization
      #
      # @param [Nokogiri::XML::Element] pub publisher element
      #
      # @return [Bib::Organization] publisher organization
      #
      def create_org(pub) # rubocop:disable Metrics/AbcSize
        name = pub.at("publisher_name").text
        abbr = pub.at("../institution[institution_name[.='#{name}']]/institution_acronym")&.text
        place = pub.at("./publisher_place") ||
          pub.at("../institution[institution_name[.='#{name}']]/institution_place")
        cont = []
        if place
          city, state = place.text.split(", ")
          cont << Bib::Address.new(street: [], city: city, state: state, country: "US")
        end
        Bib::Organization.new(
          name: [Bib::TypedLocalizedString.new(content: name)],
          abbreviation: abbr ? Bib::LocalizedString.new(content: abbr) : nil,
          address: cont,
        )
      end

      # @return [Array<Nist::Relation>]
      def parse_relation # rubocop:disable Metrics/AbcSize
        @doc.xpath("./ns:program/ns:related_item", ns: NS).map do |rel|
          rdoi = rel.at_xpath("ns:intra_work_relation|ns:inter_work_relation", ns: NS)
          id = rdoi.text.split("/")[1..].join("/").gsub(".", " ")
          fref = Bib::Formattedref.new(content: id)
          docid = Bib::Docidentifier.new(type: "NIST", content: id, primary: true)
          bibitem = ItemData.new(formattedref: fref, docidentifier: [docid])
          type = RELATION_TYPES[rdoi["relationship-type"]]
          warn "Relation type #{rdoi['relationship-type']} not found" unless type
          Relation.new(type: type, bibitem: bibitem)
        end
      end

      def parse_status
        s = @doc.at("./ns:program/ns:related_item/ns:*[@relationship-type='isPreprintOf']", ns: NS)
        return unless s

        Bib::Status.new(stage: Bib::Status::Stage.new(content: "preprint"))
      end

      # @return [Array<Bib::Place>]
      def parse_place
        @doc.xpath("institution/institution_place").map do |p|
          city, state = p.text.split(", ")
          Bib::Place.new(city: city, region: [Bib::Place::RegionType.new(iso: state)])
        end
      end

      #
      # Fetches series
      #
      # @return [Array<Bib::Series>] series
      #
      def parse_series
        prf, srs, num = pub_id.split
        sname = @series[srs] || srs
        title = Bib::Title.new(content: "#{prf} #{sname}")
        abbr = Bib::LocalizedString.new(content: srs)
        [Bib::Series.new(title: [title], abbreviation: abbr, number: num)]
      end

      #
      # Create localized string
      #
      # @param [String] content content of string
      #
      # @return [Bib::LocalizedString] localized string
      #
      def localized_string(content)
        return unless content

        Bib::LocalizedString.new(content: content, language: @doc["language"], script: "Latn")
      end
    end
  end
end
