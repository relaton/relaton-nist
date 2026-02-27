require "yaml"
require "net/http"

module Relaton
  module Nist
    class Scraper
      extend Core::DateParser

      class << self
        DOMAIN = "https://csrc.nist.gov".freeze

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

        # Parse page.
        # @param hit_data [Hash]
        # @return [Relaton::Nist::ItemData]
        def parse_page(hit_data)
          hit_data[:path] ? fetch_gh(hit_data) : parse_json(hit_data)
        end

        def fetch_gh(hit_data)
          uri = URI.parse "#{HitCollection::GHNISTDATA}#{hit_data[:path]}"
          yaml = Net::HTTP.get(uri)
          Item.from_yaml(yaml)
        end

        def parse_json(hit_data)
          item_data = from_json hit_data
          titles = fetch_titles(hit_data)
          item_data[:fetched] = ::Date.today.to_s
          item_data[:type] = "standard"
          item_data[:title] = titles
          ItemData.new(**item_data)
        end

        private

        def from_json(hit_data)
          json = hit_data[:json]
          {
            source: fetch_link(json),
            docidentifier: fetch_docid(hit_data),
            date: fetch_dates(json, hit_data[:release_date]),
            contributor: fetch_contributors(json),
            edition: fetch_edition(json),
            language: [json["language"]],
            script: [json["script"]],
            status: fetch_status(json),
            copyright: fetch_copyright(json["published-date"]),
            relation: fetch_relations_json(hit_data),
            place: fetch_place,
            keyword: fetch_keywords(json),
            ext: Ext.new(
              doctype: Doctype.new(content: "standard"),
              flavor: "nist",
              commentperiod: fetch_commentperiod_json(json),
            ),
          }
        end

        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        # Fetch docid.
        # @param hit [Hash]
        # @return [Array<Bib::Docidentifier>]
        def fetch_docid(hit)
          ids = [Bib::Docidentifier.new(content: hit[:code], type: "NIST", primary: true)]
          doi = hit[:json]["doi"]&.split("/")&.last
          ids << Bib::Docidentifier.new(content: doi, type: "DOI") if doi
          ids
        end

        # Fetch status.
        # @param doc [Hash]
        # @return [Bib::Status]
        def fetch_status(doc)
          stage = doc["status"]
          subst = doc["substage"]
          iter = iteration(doc["iteration"])
          Bib::Status.new(
            stage: Bib::Status::Stage.new(content: stage),
            substage: subst ? Bib::Status::Stage.new(content: subst) : nil,
            iteration: iter.to_s,
          )
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
        # @return [Array<Bib::Title>]
        def fetch_titles(hit_data)
          [Bib::Title.new(content: hit_data[:title], language: "en", script: "Latn")]
        end

        # Fetch dates
        # @param doc [Hash]
        # @param release_date [Date]
        # @return [Array<Bib::Date>]
        def fetch_dates(doc, release_date) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          dates = [Bib::Date.new(type: "published", at: release_date.to_s)]

          issued = safe_parse_date doc["issued-date"]
          updated = safe_parse_date doc["updated-date"]
          dates << Bib::Date.new(type: "updated", at: updated.to_s) if updated
          obsoleted = safe_parse_date doc["obsoleted-date"]
          dates << Bib::Date.new(type: "obsoleted", at: obsoleted.to_s) if obsoleted
          dates << Bib::Date.new(type: "issued", at: issued.to_s) if issued
          dates
        end

        def safe_parse_date(str)
          return unless str

          parse_date(str, str: false)
        end

        # @param doc [Hash]
        # @return [Array<Bib::Contributor>]
        def fetch_contributors(doc)
          contribs = []
          contribs += contributors_json(
            doc["authors"], "author", doc["language"], doc["script"],
          )
          contribs + contributors_json(
            doc["editors"], "editor", doc["language"], doc["script"],
          )
        end

        # @param doc [Array<Hash>]
        # @param role [String]
        # @return [Array<Bib::Contributor>]
        def contributors_json(doc, role, lang = "en", script = "Latn") # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          doc.map do |contr|
            if contr["affiliation"]
              abbrev = if contr["affiliation"]["acronym"]
                         Bib::LocalizedString.new(content: contr["affiliation"]["acronym"])
                       end
              org = Bib::Organization.new(
                name: [Bib::TypedLocalizedString.new(content: contr["affiliation"]["name"])],
                abbreviation: abbrev,
              )
            end
            if contr["surname"]
              affiliation = []
              affiliation << Bib::Affiliation.new(organization: org) if org
              entity = Bib::Person.new(
                name: full_name(contr, lang, script), affiliation: affiliation,
              )
              Bib::Contributor.new(
                person: entity,
                role: [Bib::Contributor::Role.new(type: role)],
              )
            elsif org
              Bib::Contributor.new(
                organization: org,
                role: [Bib::Contributor::Role.new(type: role)],
              )
            end
          end.compact
        end

        # @param name [Hash]
        # @param lang [String]
        # @param script [String]
        # @return [Bib::FullName]
        def full_name(name, lang, script)
          Bib::FullName.new(
            surname: Bib::LocalizedString.new(content: name["surname"], language: lang, script: script),
            forename: name_parts_forename(name["givenName"], lang, script),
            addition: name_parts(name["suffix"], lang, script),
            prefix: name_parts(name["title"], lang, script),
            completename: Bib::LocalizedString.new(content: name["fullName"], language: lang, script: script),
          )
        end

        # @param part [String, NilClass]
        # @param lang [String]
        # @param script [String]
        # @return [Array<Bib::LocalizedString>]
        def name_parts(part, lang, script)
          return [] unless part

          [Bib::LocalizedString.new(content: part, language: lang, script: script)]
        end

        # @param part [String, NilClass]
        # @param lang [String]
        # @param script [String]
        # @return [Array<Bib::FullNameType::Forename>]
        def name_parts_forename(part, lang, script)
          return [] unless part

          [Bib::FullNameType::Forename.new(content: part, language: lang, script: script)]
        end

        # @param doc [Hash]
        # @return [String, NilClass]
        def fetch_edition(doc)
          return unless doc["edition"] || doc["revision"]

          rev = doc["edition"] || doc["revision"]
          Bib::Edition.new(content: "Revision #{rev}")
        end

        # Fetch copyright.
        # @param doc [String]
        # @return [Array<Bib::Copyright>]
        def fetch_copyright(doc)
          from = doc&.match(/\d{4}/)&.to_s
          owner = Bib::ContributionInfo.new(
            organization: Bib::Organization.new(
              name: [Bib::TypedLocalizedString.new(content: "National Institute of Standards and Technology")],
              abbreviation: Bib::LocalizedString.new(content: "NIST"),
              uri: [Bib::Uri.new(content: "www.nist.gov")],
            ),
          )
          [Bib::Copyright.new(owner: [owner], from: from)]
        end

        # Fetch links.
        # @param doc [Hash]
        # @return [Array<Bib::Uri>]
        def fetch_link(doc)
          links = []
          links << Bib::Uri.new(type: "src", content: doc["uri"]) if doc["uri"]
          if doc["doi"]
            links << Bib::Uri.new(type: "doi", content: "https://doi.org/#{doc['doi']}")
          end
          links
        end

        # @return [Array<Bib::Place>]
        def fetch_place
          [Bib::Place.new(city: "Gaithersburg", region: [Bib::Place::RegionType.new(iso: "MD")])]
        end

        def fetch_relations_json(hit) # rubocop:disable Metrics/AbcSize
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
        # @return [Nist::Relation]
        def doc_relation(type, ref, uri, lang = "en", script = "Latn") # rubocop:disable Metrics/MethodLength
          if type == "supersedes"
            descr = Bib::LocalizedMarkedUpString.new(content: "supersedes", language: lang, script: script)
            t = "obsoletes"
          else t = type
          end
          ids = [Bib::Docidentifier.new(content: ref, type: "NIST", primary: true)]
          link = [Bib::Uri.new(type: "src", content: uri)]
          bib = ItemData.new(formattedref: ref, source: link, docidentifier: ids)
          Relation.new(type: t, description: descr, bibitem: bib)
        end

        # @param doc [Hash]
        # @return [Array<Bib::Keyword>]
        def fetch_keywords(doc)
          doc["keywords"].map do |kw|
            text = kw.is_a?(String) ? kw : kw.text
            Bib::Keyword.new(taxon: [Bib::LocalizedString.new(content: text)])
          end
        end

        # @param json [Hash]
        # @return [Nist::CommentPeriod, NilClass]
        def fetch_commentperiod_json(json)
          return unless json["comment-from"]

          CommentPeriod.new from: json["comment-from"], to: json["comment-to"]
        end
      end
    end
  end
end
