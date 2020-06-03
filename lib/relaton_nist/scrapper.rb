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
        item_data = if hit_data[:json]
                      from_json hit_data
                    else
                      from_csrs hit_data
                    end
        # doctype = "standard"
        titles = fetch_titles(hit_data)
        unless /^(SP|NISTIR|FIPS) / =~ item_data[:docid][0].id
          # doctype = id_cleanup(item_data[:docid][0].id)
          item_data[:docid][0] = RelatonBib::DocumentIdentifier.new(
            id: titles[0][:content].upcase, type: "NIST",
          )
        end
        item_data[:fetched] = Date.today.to_s
        item_data[:type] = "standard"
        item_data[:title] = titles
        item_data[:doctype] = "standard" # doctype

        NistBibliographicItem.new(**item_data)
      end

      private

      def from_json(hit_data)
        json = hit_data[:json]
        {
          link: fetch_link(json),
          docid: fetch_docid(json["docidentifier"]),
          date: fetch_dates(json, hit_data[:release_date]),
          contributor: fetch_contributors(json),
          edition: fetch_edition(json),
          language: [json["language"]],
          script: [json["script"]],
          docstatus: fetch_status(json, hit_data[:status]),
          copyright: fetch_copyright(json["published-date"]),
          relation: fetch_relations_json(json),
          place: ["Gaithersburg, MD"],
          keyword: fetch_keywords(json),
          commentperiod: fetch_commentperiod_json(json),
        }
      end

      def from_csrs(hit_data)
        doc = get_page hit_data[:url]
        {
          # id: fetch_id(doc),
          link: fetch_link(doc),
          docid: fetch_docid(doc),
          date: fetch_dates(doc, hit_data[:release_date]),
          contributor: fetch_contributors(doc),
          edition: fetch_edition(hit_data[:code]),
          language: ["en"],
          script: ["Latn"],
          abstract: fetch_abstract(doc),
          docstatus: fetch_status(doc, hit_data[:status]),
          copyright: fetch_copyright(doc),
          relation: fetch_relations(doc),
          series: fetch_series(doc),
          keyword: fetch_keywords(doc),
          commentperiod: fetch_commentperiod(doc),
        }
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # Strip status from doc id
      # @param id String
      # @return String
      # def id_cleanup(id)
      #   id.sub(/ \(WITHDRAWN\)/, "").sub(/ \(([^) ]+ )?DRAFT\)/i, "")
      # end

      # Get page.
      # @param path [String] page's path
      # @return [Array<Nokogiri::HTML::Document, String>]
      def get_page(url)
        uri = URI url
        resp = Net::HTTP.get_response(uri)
        %r{(?<=newLocation = 'https://' \+ window.location.hostname \+ ')(?<path>[^']+)} =~ resp.body
        if path
          uri = URI HitCollection::DOMAIN + path
          resp = Net::HTTP.get_response(uri)
        end
        Nokogiri::HTML(resp.body)
      rescue SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
             Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError,
             OpenSSL::SSL::SSLError
        raise RelatonBib::RequestError, "Could not access #{url}"
      end

      # Fetch docid.
      # @param doc [Nokogiri::HTML::Document, String]
      # @return [Array<RelatonBib::DocumentIdentifier>]
      def fetch_docid(doc)
        item_ref = if doc.is_a? String
                     doc
                   else
                     doc.at(
                       "//div[contains(@class, 'publications-detail')]/h3",
                     )&.text&.strip.sub(/(?<=\w)\([^\)]+\)$/) { |m| " " + m.upcase}.squeeze " "
                   end
        item_ref ||= "?"
        [RelatonBib::DocumentIdentifier.new(id: item_ref, type: "NIST")]
      end

      # Fetch id.
      # @param doc [Nokogiri::HTML::Document]
      # @return [String]
      # def fetch_id(doc)
      #   doc.at("//div[contains(@class, 'publications-detail')]/h3").text.
      #     strip.gsub(/\s/, "")
      # end

      # Fetch status.
      # @param doc [Nokogiri::HTML::Document, Hash]
      # @param status [String]
      # @return [RelatonNist::DocumentStatus]
      def fetch_status(doc, status)
        if doc.is_a? Hash
          stage = doc["status"]
          subst = doc["substage"]
          iter = doc["iteration"] == "initial" ? 1 : doc["iteration"]
        else
          case status
          when "draft (obsolete)"
            stage = "draft-public"
            subst = "withdrawn"
          when "retired draft"
            stage = "draft-public"
            subst = "retired"
          when "withdrawn"
            stage = "final"
            subst = "withdrawn"
          when /^draft/
            stage = "draft-public"
            subst = "active"
          else
            stage = status
            subst = "active"
          end

          iter = nil
          if stage.include? "draft"
            iter = 1
            history = doc.xpath("//span[@id='pub-history-container']/a"\
                                "|//span[@id='pub-history-container']/span")
            history.each_with_index do |h, idx|
              next if h.name == "a"

              iter = idx + 1 if idx.positive?
              break
            end
          end
        end

        RelatonNist::DocumentStatus.new stage: stage, substage: subst, iteration: iter.to_s
      end

      # Fetch titles.
      # @param hit_data [Hash]
      # @return [Array<Hash>]
      def fetch_titles(hit_data)
        [{ content: hit_data[:title], language: "en", script: "Latn", format: "text/plain" }]
      end

      # Fetch dates
      # @param doc [Nokogiri::HTML::Document]
      # @param release_date [Date]
      # @return [Array<Hash>]
      def fetch_dates(doc, release_date)
        dates = [{ type: "published", on: release_date.to_s }]

        if doc.is_a? Hash
          issued = RelatonBib.parse_date doc["issued-date"]
          updated = RelatonBib.parse_date doc["updated-date"]
          dates << { type: "updated", on: updated.to_s } if updated
          obsoleted = RelatonBib.parse_date doc["obsoleted-date"]
          dates << { type: "obsoleted", on: obsoleted.to_s } if obsoleted
        else
          d = doc.at("//span[@id='pub-release-date']").text.strip
          issued = RelatonBib.parse_date d
        end
        dates << { type: "issued", on: issued.to_s }
        dates
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      # @param doc [Nokogiri::HTML::Document, Hash]
      # @return [Array<RelatonBib::ContributionInfo>]
      def fetch_contributors(doc)
        contribs = []
        if doc.is_a? Hash
          contribs += contributors_json(
            doc["authors"], "author", doc["language"], doc["script"]
          )
          contribs + contributors_json(
            doc["editors"], "editor", doc["language"], doc["script"]
          )
        else
          name = "National Institute of Standards and Technology"
          org = RelatonBib::Organization.new(
            name: name, url: "www.nist.gov", abbreviation: "NIST",
          )
          contribs << RelatonBib::ContributionInfo.new(entity: org, role: [type: "publisher"])
          authors = doc.at('//h4[.="Author(s)"]/following-sibling::p')
          contribs += contributors(authors, "author")
          editors = doc.at('//h4[.="Editor(s)"]/following-sibling::p')
          contribs + contributors(editors, "editor")
        end
      end

      # @param doc [Array<Hash>]
      # @param role [String]
      # @return [Array<RelatonBib::ContributionInfo>]
      def contributors_json(doc, role, lang = "en", script = "Latn")
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
            affiliation = RelatonBib::Affiliation.new organization: org
            entity = RelatonBib::Person.new(
              name: full_name(contr, lang, script), affiliation: [affiliation],
            )
          else
            entity = org
          end
          RelatonBib::ContributionInfo.new entity: entity, role: [type: role]
        end
      end

      # rubocop:disable Metrics/CyclomaticComplexity
      # @param doc [Nokogiri::HTML::Element, Array<Hash>]
      # @param role [String]
      # @return [Array<RelatonBib::ContributionInfo>]
      def contributors(doc, role, lang = "en", script = "Latn")
        return [] if doc.nil?

        doc.text.split(", ").map do |contr|
          /(?<an>.+?)(\s+\((?<abbrev>.+?)\))?$/ =~ contr
          if abbrev && an.downcase !~ /(task|force|group)/ && an.split.size.between?(2, 3)
            fullname = RelatonBib::FullName.new(
              completename: RelatonBib::LocalizedString.new(an, lang, script),
            )
            case abbrev
            when "NIST"
              org_name = "National Institute of Standards and Technology"
              url = "www.nist.gov"
            when "MITRE"
              org_name = abbrev
              url = "www.mitre.org"
            else
              org_name = abbrev
              url = nil
            end
            org = RelatonBib::Organization.new name: org_name, url: url, abbreviation: abbrev
            affiliation = RelatonBib::Affiliation.new organization: org
            entity = RelatonBib::Person.new(
              name: fullname, affiliation: [affiliation],
            )
          else
            entity = RelatonBib::Organization.new name: an, abbreviation: abbrev
          end
          RelatonBib::ContributionInfo.new entity: entity, role: [type: role]
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength

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

      # @param doc [String, Hash]
      # @return [String, NilClass]
      def fetch_edition(doc)
        if doc.is_a? Hash
          return unless doc["edition"]

          rev = doc["edition"]
        else
          return unless /(?<=Rev\.\s)(?<rev>\d+)/ =~ doc
        end

        "Revision #{rev}"
      end

      # Fetch abstracts.
      # @param doc [Nokigiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_abstract(doc)
        abstract_content = doc.xpath(
          '//div[contains(@class, "pub-abstract-callout")]/div[1]/p',
        ).text
        [{
          content: abstract_content,
          language: "en",
          script: "Latn",
          format: "text/plain",
        }]
      end

      # Fetch copyright.
      # @param doc [Nokogiri::HTL::Document, String]
      # @return [Array<Hash>]
      def fetch_copyright(doc)
        name = "National Institute of Standards and Technology"
        url = "www.nist.gov"
        d = if doc.is_a? String then doc
            else
              doc.at("//span[@id='pub-release-date']").text.strip
            end
        from = d.match(/\d{4}/).to_s
        [{ owner: [{ name: name, abbreviation: "NIST", url: url }], from: from }]
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

      # Fetch links.
      # @param doc [Nokogiri::HTML::Document, Hash]
      # @return [Array<Hash>]
      def fetch_link(doc)
        links = []
        if doc.is_a? Hash
          links << { type: "uri", content: doc["uri"] } if doc["uri"]
          doi = "https://doi.org/" + doc["doi"] if doc["doi"]
        else
          pub = doc.at "//p/strong[contains(., 'Publication:')]"
          pdf = pub&.at "./following-sibling::a[.=' Local Download']"
          doi = pub&.at("./following-sibling::a[contains(.,'(DOI)')]")&.attr :href
          links << { type: "pdf", content: pdf[:href] } if pdf
        end
        links << { type: "doi", content: doi } if doi
        links
      end
      # rubocop:enable Metrics/MethodLength

      # Fetch relations.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<RelatonBib::DocumentRelation>]
      def fetch_relations(doc)
        relations = doc.xpath('//span[@id="pub-supersedes-container"]/a').map do |r|
          doc_relation "supersedes", r.text, DOMAIN + r[:href]
        end

        relations += doc.xpath('//span[@id="pub-part-container"]/a').map do |r|
          doc_relation "partOf", r.text, DOMAIN + r[:href]
        end

        relations + doc.xpath('//span[@id="pub-related-container"]/a').map do |r|
          doc_relation "updates", r.text, DOMAIN + r[:href]
        end
      end
      # rubocop:enable Metrics/AbcSize

      def fetch_relations_json(doc)
        relations = doc["supersedes"].map do |r|
          doc_relation "supersedes", r["docidentifier"], r["uri"]
        end

        relations + doc["superseded-by"].map do |r|
          doc_relation "updates", r["docidentifier"], r["uri"]
        end
      end

      # @param type [String]
      # @param ref [String]
      # @param uri [String]
      # @return [RelatonBib::DocumentRelation]
      def doc_relation(type, ref, uri, lang = "en", script = "Latn")
        RelatonBib::DocumentRelation.new(
          type: type,
          bibitem: RelatonBib::BibliographicItem.new(
            formattedref: RelatonBib::FormattedRef.new(
              content: ref, language: lang, script: script, format: "text/plain",
            ),
            link: [RelatonBib::TypedUri.new(type: "src", content: uri)],
          ),
        )
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<RelatonBib::Series>]
      def fetch_series(doc)
        series = doc.xpath "//span[@id='pub-history-container']/a"\
          "|//span[@id='pub-history-container']/span"
        series.map.with_index do |s, idx|
          next if s.name == "span"

          iter = if idx.zero? then "I"
                 else idx + 1
                 end

          content = s.text.match(/^[^\(]+/).to_s.strip.squeeze " "

          ref = case s.text
                when /^Draft/
                  content.match(/(?<=Draft\s).+/).to_s + " (#{iter}PD)"
                when /\(Draft\)/ then content + " (#{iter}PD)"
                else content
                end

          fref = RelatonBib::FormattedRef.new(
            content: ref, language: "en", script: "Latn", format: "text/plain",
          )
          RelatonBib::Series.new(formattedref: fref)
        end.select { |s| s }
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      # @param doc [Nokogiri::HTML::Document, Hash]
      # @return [Array<RelatonNist::Keyword>]
      def fetch_keywords(doc)
        kws = if doc.is_a? Hash
                doc["keywords"]
              else
                doc.xpath "//span[@id='pub-keywords-container']/span"
              end
        kws.map { |kw| kw.is_a?(String) ? kw : kw.text }
      end

      # rubocop:disable Metrics/AbcSize
      # @param doc [Nokogiri::HTML::Document]
      # @return [RelatonNist::CommentPeriod, NilClass]
      def fetch_commentperiod(doc)
        cp = doc.at "//span[@id='pub-comments-due']"
        return unless cp

        to = Date.strptime cp.text.strip, "%B %d, %Y"

        d = doc.at("//span[@id='pub-release-date']").text.strip
        from = Date.strptime(d, "%B %Y").to_s

        ex = doc.at "//strong[contains(.,'The comment closing date has been "\
        "extended to')]"
        ext = ex&.text&.match(/\w+\s\d{2},\s\d{4}/).to_s
        extended = ext.empty? ? nil : Date.strptime(ext, "%B %d, %Y")
        CommentPeriod.new from: from, to: to, extended: extended
      end
      # rubocop:enable Metrics/AbcSize

      # @param json [Hash]
      # @return [RelatonNist::CommentPeriod, NilClass]
      def fetch_commentperiod_json(json)
        return unless json["comment-from"]

        CommentPeriod.new from: json["comment-from"], to: json["comment-to"]
      end
    end
  end
end
