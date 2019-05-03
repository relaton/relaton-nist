require "relaton_bib"

module NistBib
  class Scrapper
    class << self
      DOMAIN = "https://csrc.nist.gov".freeze

      # Parse page.
      # @param hit_data [Hash]
      # @return [Hash]
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def parse_page(hit_data)
        doc = get_page hit_data[:url]

        NistBibliographicItem.new(
          fetched: Date.today.to_s,
          type: nil,
          titles: fetch_titles(hit_data),
          link: fetch_link(doc),
          docid: fetch_docid(doc),
          dates: fetch_dates(doc),
          contributors: fetch_contributors(doc),
          edition: nil,
          language: ["en"],
          script: ["Latn"],
          abstract: fetch_abstract(doc),
          docstatus: fetch_status(doc),
          copyright: fetch_copyright(doc),
          relations: fetch_relations(doc),
          nistseries: fetch_nistseries(doc),
          keyword: fetch_keywords(doc),
          commentperiod: fetch_commentperiod(doc),
          # ics:          [],
          # workgroup:    nil,
          # id:           fetch_id(doc),
        )
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
      # @return [Hash]
      def fetch_docid(doc)
        item_ref = doc.at("//div[contains(@class, 'publications-detail')]/h3").
          text.strip
        return [RelatonBib::DocumentIdentifier.new(type: "nist", id: "?")] unless item_ref

        [RelatonBib::DocumentIdentifier.new(id: item_ref, type: "nist")]
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
      def fetch_status(doc)
        status = if doc.at "//p/strong[text()='Withdrawn:']"
                   "withdrawn"
                 else
                   item_ref = doc.at(
                     "//div[contains(@class, 'publications-detail')]/h3"
                   ).text.strip
                   wip = item_ref.match(/(?<=\()\w+/).to_s
                   case wip
                   when "DRAFT"
                     "draft"
                   else
                     "published"
                   end
                 end
        RelatonBib::DocumentStatus.new(
          RelatonBib::LocalizedString.new(status, "en", "Latn"),
        )
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
      def fetch_dates(doc)
        dates = []
        d = doc.at("//strong[text()='Date Published:']/../text()[2]").text.strip
        issued_date = Date.strptime(d, "%B %Y").to_s
        dates << { type: "issued", on: issued_date } unless issued_date.empty?

        pd = d.match(/\d{2}-\d{2}-\d{4}/)
        publish_date = pd ? Date.strptime(pd.to_s, "%m-%d-%Y").to_s : issued_date
        dates << { type: "published", on: publish_date } unless publish_date.empty?
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
        d = doc.at("//strong[text()='Date Published:']/../text()[2]").text.strip
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
        relations = doc.xpath('//strong[.="Supersedes:"]/following-sibling::a').map do |r|
          doc_relation "supersedes", r
        end

        relations += doc.xpath(
          '//strong[text()="Other Parts of this Publication:"]/following-sibling::a',
        ).map { |r| doc_relation "partOf", r }

        relations + doc.xpath(
          '//strong[text()="Related NIST Publications:"]/following-sibling::a',
        ).map { |r| doc_relation "updates", r }
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

      def fetch_nistseries(doc)
        doc.xpath("//p/strong[.='Document History:']/following-sibling::*[not(self::br)]").each do |s|
          NistSeries::ABBREVIATIONS.each do |k, _v|
            return NistSeries.new k if s.text.include? k
          end
        end
        nil
      end

      def fetch_keywords(doc)
        kws = doc.at "//h4[.='Keywords']/following-sibling::text()"
        return [] unless kws

        kws.text.strip.split("; ").map { |kw| Keyword.new kw }
      end

      def fetch_commentperiod(doc)
        cp = doc.at "//strong[.='Comments Due:']/following-sibling::text()"
        return unless cp

        to = Date.strptime cp.text.strip, "%B %d, %Y"

        d = doc.at("//strong[text()='Date Published:']/../text()[2]").text.strip
        from = Date.strptime(d, "%B %Y").to_s

        ex = doc.at "//strong[contains(.,'The comment closing date has been extended to')]"
        ext = ex&.text&.match(/\w+\s\d{2},\s\d{4}/).to_s
        extended = ext.empty? ? nil : Date.strptime(ext, "%B %d, %Y")
        CommentPeriod.new from, to, extended
      end
    end
  end
end
