require "relaton_bib"

module RelatonNist
  class Scrapper
    class << self
      DOMAIN = "https://csrc.nist.gov".freeze

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

      # Parse page.
      # @param hit_data [Hash]
      # @return [Hash]
      def parse_page(hit_data)
        hit_data[:path] ? fetch_gh(hit_data) : parse_json(hit_data)
      end

      def fetch_gh(hit_data)
        yaml = OpenURI.open_uri "#{HitCollection::GHNISTDATA}#{hit_data[:path]}"
        hash = YAML.safe_load yaml
        hash["fetched"] = Date.today.to_s
        NistBibliographicItem.from_hash hash
      end

      def parse_json(hit_data)
        item_data = from_json hit_data
        titles = fetch_titles(hit_data)
        # unless /^(SP|NISTIR|FIPS) /.match? item_data[:docid][0].id
        #   item_data[:docid][0] = RelatonBib::DocumentIdentifier.new(
        #     id: titles[0][:content].upcase, type: "NIST", primary: true,
        #   )
        # end
        item_data[:fetched] = Date.today.to_s
        item_data[:type] = "standard"
        item_data[:title] = titles
        item_data[:doctype] = RelatonBib::DocumentType.new(type: "standard")

        NistBibliographicItem.new(**item_data)
      end

      private

      def from_json(hit_data)
        json = hit_data[:json]
        {
          link: fetch_link(json),
          docid: fetch_docid(hit_data),
          date: fetch_dates(json, hit_data[:release_date]),
          contributor: fetch_contributors(json),
          edition: fetch_edition(json),
          language: [json["language"]],
          script: [json["script"]],
          docstatus: fetch_status(json), # hit_data[:status]),
          copyright: fetch_copyright(json["published-date"]),
          relation: fetch_relations_json(hit_data),
          place: ["Gaithersburg, MD"],
          keyword: fetch_keywords(json),
          commentperiod: fetch_commentperiod_json(json),
        }
      end

      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # Fetch docid.
      # @param hit [RelatonHist::Hit]
      # @return [Array<RelatonBib::DocumentIdentifier>]
      def fetch_docid(hit)
        # item_ref = docid
        # json["docidentifier"]
        # item_ref ||= "?"
        # item_ref.sub!(/\sAddendum$/, "-Add")
        ids = [RelatonBib::DocumentIdentifier.new(id: hit[:code], type: "NIST", primary: true)]
        doi = hit[:json]["doi"]&.split("/")&.last
        ids << RelatonBib::DocumentIdentifier.new(id: doi, type: "DOI") if doi
        ids
      end

      # Fetch status.
      # @param doc [Hash]
      # @return [RelatonNist::DocumentStatus]
      def fetch_status(doc)
        stage = doc["status"]
        subst = doc["substage"]
        iter = iteration(doc["iteration"])
        RelatonNist::DocumentStatus.new stage: stage, substage: subst, iteration: iter.to_s
      end

      def iteration(iter)
        case iter
        when "initial", "ipd" then 1
        when /(\d)pd/i then $1
        else iter
        end
      end

      # Fetch titles.
      # @param hit_data [Hash]
      # @return [Array<Hash>]
      def fetch_titles(hit_data)
        [{ content: hit_data[:title], language: "en", script: "Latn",
           format: "text/plain" }]
      end

      # Fetch dates
      # @param doc [Hash]
      # @param release_date [Date]
      # @return [Array<Hash>]
      def fetch_dates(doc, release_date) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        dates = [{ type: "published", on: release_date.to_s }]

        # if doc.is_a? Hash
        issued = RelatonBib.parse_date doc["issued-date"]
        updated = RelatonBib.parse_date doc["updated-date"]
        dates << { type: "updated", on: updated.to_s } if updated
        obsoleted = RelatonBib.parse_date doc["obsoleted-date"]
        dates << { type: "obsoleted", on: obsoleted.to_s } if obsoleted
        # else
        #   d = doc.at("//span[@id='pub-release-date']")&.text&.strip
        #   issued = RelatonBib.parse_date d
        # end
        dates << { type: "issued", on: issued.to_s } if issued
        dates
      end

      # @param doc [Hash]
      # @return [Array<RelatonBib::ContributionInfo>]
      def fetch_contributors(doc)
        contribs = []
        # if doc.is_a? Hash
        contribs += contributors_json(
          doc["authors"], "author", doc["language"], doc["script"]
        )
        contribs + contributors_json(
          doc["editors"], "editor", doc["language"], doc["script"]
        )
      end

      # @param doc [Array<Hash>]
      # @param role [String]
      # @return [Array<RelatonBib::ContributionInfo>]
      def contributors_json(doc, role, lang = "en", script = "Latn") # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        doc.map do |contr|
          if contr["affiliation"]
            if contr["affiliation"]["acronym"]
              abbrev = RelatonBib::LocalizedString.new(contr["affiliation"]["acronym"])
            end
            org = RelatonBib::Organization.new(
              name: contr["affiliation"]["name"], abbreviation: abbrev,
            )
          end
          if contr["surname"]
            affiliation = []
            affiliation << RelatonBib::Affiliation.new(organization: org) if org
            entity = RelatonBib::Person.new(
              name: full_name(contr, lang, script), affiliation: affiliation,
            )
          elsif org
            entity = org
          end
          if entity
            RelatonBib::ContributionInfo.new entity: entity, role: [type: role]
          end
        end.compact
      end

      # @param name [Hash]
      # @param lang [Strong]
      # @param script [String]
      # @return [RelatonBib::FullName]
      def full_name(name, lang, script)
        RelatonBib::FullName.new(
          surname: RelatonBib::LocalizedString.new(name["surname"], lang, script),
          forename: name_parts(name["givenName"], lang, script),
          addition: name_parts(name["suffix"], lang, script),
          prefix: name_parts(name["title"], lang, script),
          completename: RelatonBib::LocalizedString.new(name["fullName"], lang, script),
        )
      end

      # @param part [String, NilClass]
      # @param lang [Strong]
      # @param script [String]
      # @return [Array<RelatonBib::LocalizedString>]
      def name_parts(part, lang, script)
        return [] unless part

        [RelatonBib::LocalizedString.new(part, lang, script)]
      end

      # @param doc [Hash]
      # @return [String, NilClass]
      def fetch_edition(doc)
        # if doc.is_a? Hash
        return unless doc["edition"] || doc["revision"]

        rev = doc["edition"] || doc["revision"]
        "Revision #{rev}"
      end

      # Fetch copyright.
      # @param doc [Nokogiri::HTL::Document, String]
      # @return [Array<Hash>]
      def fetch_copyright(doc)
        name = "National Institute of Standards and Technology"
        url = "www.nist.gov"
        from = doc&.match(/\d{4}/)&.to_s
        [{ owner: [{ name: name, abbreviation: "NIST", url: url }], from: from }]
      end

      # Fetch links.
      # @param doc [Hash]
      # @return [Array<Hash>]
      def fetch_link(doc)
        links = []
        links << { type: "src", content: doc["uri"] } if doc["uri"]
        if doc["doi"]
          links << { type: "doi", content: "https://doi.org/#{doc['doi']}" }
        end
        links
      end

      def fetch_relations_json(hit)
        doc = hit[:json]
        relations = doc["supersedes"].map do |r|
          doc_relation "supersedes", hit[:code], r["uri"]
        end

        relations + doc["superseded-by"].map do |r|
          doc_relation "updates", hit[:code], r["uri"]
        end
      end

      # @param type [String]
      # @param ref [String]
      # @param uri [String]
      # @return [RelatonNist::DocumentRelation]
      def doc_relation(type, ref, uri, lang = "en", script = "Latn") # rubocop:disable Metrics/MethodLength
        if type == "supersedes"
          descr = RelatonBib::FormattedString.new(content: "supersedes", language: lang, script: script)
          t = "obsoletes"
        else t = type
        end
        ids = [RelatonBib::DocumentIdentifier.new(id: ref, type: "NIST", primary: true)]
        fref = RelatonBib::FormattedRef.new(content: ref, language: lang, script: script, format: "text/plain")
        link = [RelatonBib::TypedUri.new(type: "src", content: uri)]
        bib = RelatonBib::BibliographicItem.new(formattedref: fref, link: link, docid: ids)
        DocumentRelation.new(type: t, description: descr, bibitem: bib)
      end

      # @param doc [Hash]
      # @return [Array<RelatonNist::Keyword>]
      def fetch_keywords(doc)
        doc["keywords"].map { |kw| kw.is_a?(String) ? kw : kw.text }
      end

      # @param json [Hash]
      # @return [RelatonNist::CommentPeriod, NilClass]
      def fetch_commentperiod_json(json)
        return unless json["comment-from"]

        CommentPeriod.new from: json["comment-from"], to: json["comment-to"]
      end
    end
  end
end
