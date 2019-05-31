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
        doc = get_page hit_data[:url]

        docid = fetch_docid(doc)
        doctype = "standard"
        titles = fetch_titles(hit_data)
        unless /^(SP|NISTIR|FIPS) /.match docid[0].id
          doctype = id_cleanup(docid[0].id)
          docid[0] = RelatonBib::DocumentIdentifier.new(id: titles[0][:content], type: "NIST")
        end

        NistBibliographicItem.new(
          fetched: Date.today.to_s,
          type: "standard",
          # id: fetch_id(doc),
          titles: titles,
          link: fetch_link(doc),
          docid: docid,
          dates: fetch_dates(doc, hit_data[:release_date]),
          contributors: fetch_contributors(doc),
          edition: fetch_edition(hit_data[:code]),
          language: ["en"],
          script: ["Latn"],
          abstract: fetch_abstract(doc),
          docstatus: fetch_status(doc, hit_data[:status]),
          copyright: fetch_copyright(doc),
          relations: fetch_relations(doc),
          series: fetch_series(doc),
          keyword: fetch_keywords(doc),
          commentperiod: fetch_commentperiod(doc),
          doctype: doctype,
        )
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # Strip status from doc id
      # @param id String
      # @return String
      def id_cleanup(id)
        id.sub(/ \(WITHDRAWN\)/, "").sub(/ \(([^) ]+ )?DRAFT\)/i, "")
      end

      private

      # Get page.
      # @param path [String] page's path
      # @return [Array<Nokogiri::HTML::Document, String>]
      def get_page(url)
        uri = URI url
        resp = Net::HTTP.get_response(uri) # .encode("UTF-8")
        Nokogiri::HTML(resp.body)
      end

      # Fetch docid.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<RelatonBib::DocumentIdentifier>]
      def fetch_docid(doc)
        item_ref = doc.at("//div[contains(@class, 'publications-detail')]/h3").
          text.strip
        return [RelatonBib::DocumentIdentifier.new(type: "NIST", id: "?")] unless item_ref

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
      # @param doc [Nokogiri::HTML::Document]
      # @param status [String]
      # @return [Hash]
      def fetch_status(doc, status)
        case status
        when "draft (withdrawn)"
          stage = "draft-public"
          subst = "withdrawn"
        when "retired draft"
          stage = "draft-public"
          subst = "retired"
        when "withdrawn"
          stage = "final"
          subst = "withdrawn"
        when "draft"
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
            # iter = if lsif idx < (history.size - 1) && !history.last.text.include?("Draft")
            #          "final"
            #        elsif idx.positive? then idx + 1
            #        end
            break
          end
        end

        # if doc.at "//p/strong[text()='Withdrawn:']"
        #   substage = "withdrawn"
        # else
        #   substage = "active"
        #   item_ref = doc.at(
        #     "//div[contains(@class, 'publications-detail')]/h3",
        #   ).text.strip
        #   wip = item_ref.match(/(?<=\()\w+/).to_s
        #   stage = "draft-public" if wip == "DRAFT"
        # end
        RelatonNist::DocumentStatus.new stage: stage, substage: subst, iteration: iter
      end

      # Fetch titles.
      # @param hit_data [Hash]
      # @return [Array<Hash>]
      def fetch_titles(hit_data)
        [{ content: hit_data[:title], language: "en", script: "Latn", format: "text/plain" }]
      end

      # Fetch dates
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_dates(doc, release_date)
        dates = [{ type: "published", on: release_date.to_s }]

        d = doc.at("//span[@id='pub-release-date']").text.strip
        date = if /(?<date>\w+\s\d{4})/ =~ d
                 Date.strptime(date, "%B %Y")
               elsif /(?<date>\w+\s\d{1,2},\s\d{4})/ =~ d
                 Date.strptime(date, "%B %d, %Y")
               end
        dates << { type: "issued", on: date.to_s }

        dates
      end

      def fetch_contributors(doc)
        name = "National Institute of Standards and Technology"
        org = RelatonBib::Organization.new(
          name: name, url: "www.nist.gov", abbreviation: "NIST",
        )
        contribs = [
          RelatonBib::ContributionInfo.new(entity: org, role: ["publisher"]),
        ]

        authors = doc.at('//h4[.="Author(s)"]/following-sibling::p')
        contribs += contributors(authors, "author")

        editors = doc.at('//h4[.="Editor(s)"]/following-sibling::p')
        contribs + contributors(editors, "editor")
      end

      # rubocop:disable Metrics/CyclomaticComplexity
      def contributors(doc, role)
        return [] if doc.nil?

        doc.text.split(", ").map do |contr|
          /(?<an>.+?)(\s+\((?<abbrev>.+?)\))?$/ =~ contr
          if abbrev && an.downcase !~ /(task|force|group)/ && an.split.size.between?(2, 3)
            fullname = RelatonBib::FullName.new(
              completename: RelatonBib::LocalizedString.new(an, "en", "Latn"),
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
            affiliation = RelatonBib::Affilation.new org
            entity = RelatonBib::Person.new(
              name: fullname, affiliation: [affiliation], contacts: [],
            )
          else
            entity = RelatonBib::Organization.new name: an, abbreviation: abbrev
          end
          RelatonBib::ContributionInfo.new entity: entity, role: [role]
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      def fetch_edition(code)
        return unless /(?<=Rev\.\s)(?<rev>\d+)/ =~ code

        "Revision #{rev}"
      end

      # Fetch abstracts.
      # @param doc [Nokigiri::HTML::Document]
      # @return [Array<Array>]
      def fetch_abstract(doc)
        abstract_content = doc.xpath('//div[contains(@class, "pub-abstract-callout")]/div[1]/p').text
        [{
          content: abstract_content,
          language: "en",
          script: "Latn",
          format: "text/plain",
        }]
      end

      # Fetch copyright.
      # @param title [String]
      # @return [Hash]
      def fetch_copyright(doc)
        name = "National Institute of Standards and Technology"
        url = "www.nist.gov"
        d = doc.at("//span[@id='pub-release-date']").text.strip
        from = d.match(/\d{4}/).to_s
        { owner: { name: name, abbreviation: "NIST", url: url }, from: from }
      end

      # Fetch links.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_link(doc)
        pub = doc.at "//p/strong[.='Publication:']"
        links = []
        pdf = pub.at "./following-sibling::a[.=' Local Download']"
        links << { type: "pdf", content: pdf[:href] } if pdf
        doi = pub.at("./following-sibling::a[contains(.,'(DOI)')]")
        links << { type: "doi", content: doi[:href] } if doi
        links
      end

      # Fetch relations.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_relations(doc)
        relations = doc.xpath('//span[@id="pub-supersedes-container"]/a').map do |r|
          doc_relation "supersedes", r
        end

        relations += doc.xpath('//span[@id="pub-part-container"]/a').map do |r|
          doc_relation "partOf", r
        end

        relations + doc.xpath('//span[@id="pub-related-container"]/a').map do |r|
          doc_relation "updates", r
        end
      end

      def doc_relation(type, ref)
        RelatonBib::DocumentRelation.new(
          type: type,
          bibitem: RelatonBib::BibliographicItem.new(
            formattedref: RelatonBib::FormattedRef.new(
              content: ref.text, language: "en", script: "Latn", format: "text/plain",
            ),
            link: [RelatonBib::TypedUri.new(type: "src", content: DOMAIN + ref[:href])],
          ),
        )
      end

      def fetch_series(doc)
        series = doc.xpath "//span[@id='pub-history-container']/a"\
          "|//span[@id='pub-history-container']/span"
        series.map.with_index do |s, idx|
          next if s.name == "span"

          iter = if idx.zero? then "I"
                   #  elsif status == "final" && idx == (series.size - 1) then "F"
                 else idx + 1
                 end

          content = s.text.match(/^[^\(]+/).to_s.strip.gsub "  ", " "

          ref = case content.match(/\w+/).to_s
                when "Draft" then content.match(/(?<=Draft\s).+/).to_s + " (#{iter}PD)"
                end

          fref = RelatonBib::FormattedRef.new(
            content: ref, language: "en", script: "Latn", format: "text/plain",
          )
          RelatonBib::Series.new(formattedref: fref)
        end.select { |s| s }
      end

      def fetch_keywords(doc)
        kws = doc.xpath "//span[@id='pub-keywords-container']/span"
        kws.map { |kw| Keyword.new kw.text }
      end

      def fetch_commentperiod(doc)
        cp = doc.at "//span[@id='pub-comments-due']"
        return unless cp

        to = Date.strptime cp.text.strip, "%B %d, %Y"

        d = doc.at("//span[@id='pub-release-date']").text.strip
        from = Date.strptime(d, "%B %Y").to_s

        ex = doc.at "//strong[contains(.,'The comment closing date has been extended to')]"
        ext = ex&.text&.match(/\w+\s\d{2},\s\d{4}/).to_s
        extended = ext.empty? ? nil : Date.strptime(ext, "%B %d, %Y")
        CommentPeriod.new from, to, extended
      end
    end
  end
end
