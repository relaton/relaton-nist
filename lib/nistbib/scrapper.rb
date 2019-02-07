require 'iso_bib_item'

module NistBib
  module Scrapper
    class << self
      DOMAIN = 'https://csrc.nist.gov'

      # Parse page.
      # @param hit_data [Hash]
      # @return [Hash]
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def parse_page(hit_data)
        doc = get_page hit_data[:url]

        IsoBibItem::IsoBibliographicItem.new(
          docid:        fetch_docid(doc),
          edition:      nil,
          language:     ['en'],
          script:       ['Latn'],
          titles:       fetch_titles(hit_data),
          type:         nil,
          docstatus:    fetch_status(doc),
          ics:          [],
          dates:        fetch_dates(doc),
          contributors: fetch_contributors,
          workgroup:    nil,
          abstract:     fetch_abstract(doc),
          copyright:    fetch_copyright(doc),
          link:         fetch_link(doc, hit_data[:url]),
          relations:    fetch_relations(doc)
        )
      end

      private

      # Get page.
      # @param path [String] page's path
      # @return [Array<Nokogiri::HTML::Document, String>]
      def get_page(url)
        uri = URI url
        resp = Net::HTTP.get_response(uri)#.encode("UTF-8")
        Nokogiri::HTML(resp.body)
      end

      # Fetch docid.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Hash]
      def fetch_docid(doc)
        item_ref = doc.at("//div[contains(@class, 'publications-detail')]/h3").text.strip
        unless item_ref
          return { project_number: '?', part_number: '', prefix: nil, type: 'NIST', id: '?' }
        end
        m = item_ref.match(/(?<=\s)(?<project>[\d-]+)(?<vol>\sVol\.\s)?(?<part>(?(<vol>)\d+|))/)
        {
          project_number: m[:project],
          part_number: m[:part],
          subpart_number: nil,
          prefix: nil,
          type: 'NIST',
          id: item_ref
        }
      end

      # Fetch status.
      # @param doc [Nokogiri::HTML::Document]
      # @param status [String]
      # @return [Hash]
      def fetch_status(doc)
        withdrawn = doc.at "//p/strong[text()='Withdrawn:']"
        return { status: 'withdrawn', stage: '95', substage: '99' } if withdrawn

        item_ref = doc.at("//div[contains(@class, 'publications-detail')]/h3").text.strip
        wip = item_ref.match(/(?<=\()\w+/).to_s
        case wip
        when 'DRAFT'
          { status: 'working-draft', stage: '20', substage: '20' }
        # when 'RETIRED DRAFT'
        #   { status: 'committee-draft', stage: '30', substage: '00' }
        else
          { status: 'published', stage: '60', substage: '60' }
        end
      end

      # Fetch titles.
      # @param hit_data [Hash]
      # @return [Array<Hash>]
      def fetch_titles(hit_data)
        titles = hit_data[:title].split ' - '
        # case titles.size
        # when 0
        #   intro, main, part = nil, "", nil
        # when 1
          intro, main, part = nil, titles[0], nil
        # when 2
        #   if /^(Part|Partie) \d+:/ =~ titles[1]
        #     intro, main, part = nil, titles[0], titles[1]
        #   else
        #     intro, main, part = titles[0], titles[1], nil
        #   end
        # when 3
        #   intro, main, part = titles[0], titles[1], titles[2]
        # else
        #   intro, main, part = titles[0], titles[1], titles[2..-1]&.join(" -- ")
        # end
        [{
          title_intro: intro,
          title_main:  main,
          title_part:  part,
          language:    'en',
          script:      'Latn'
        }]
      end

      # Fetch dates
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_dates(doc)
        dates = []
        d = doc.at("//strong[text()='Date Published:']/../text()[2]").text.strip
        publish_date = Date.strptime(d, '%B %Y').to_s
        unless publish_date.empty?
          dates << { type: 'published', on: publish_date }
        end
        dates
      end

      def fetch_contributors
        name = 'National Institute of Standards and Technology'
        url = 'www.nist.gov'
        [{ entity: { name: name, url: url, abbreviation: 'NIST' }, roles: ['publisher'] }]
      end

      # Fetch abstracts.
      # @param doc [Nokigiri::HTML::Document]
      # @return [Array<Array>]
      def fetch_abstract(doc)
        abstract_content = doc.xpath('//div[contains(@class, "pub-abstract-callout")]/div[1]/p').text
        [{
          content:  abstract_content,
          language: 'en',
          script:   'Latn'
        }]
      end

      # Fetch copyright.
      # @param title [String]
      # @return [Hash]
      def fetch_copyright(doc)
        name = 'National Institute of Standards and Technology'
        url = 'www.nist.gov'
        d = doc.at("//strong[text()='Date Published:']/../text()[2]").text.strip
        from = d.match(/\d{4}$/).to_s
        { owner: { name: name, abbreviation: 'NIST', url: url }, from: from }
      end

      # Fetch links.
      # @param doc [Nokogiri::HTML::Document]
      # @param url [String]
      # @return [Array<Hash>]
      def fetch_link(doc, url)
        links = [{ type: 'src', content: url }]
        obp_elms = doc.at_css('a[data-identity="first-link-display"]')
        links << { type: 'obp', content: obp_elms[:href] } if obp_elms
        links
      end

      # Fetch relations.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      # rubocop:disable Metrics/MethodLength
      def fetch_relations(doc)
        relations = doc.xpath('//strong[text()="Other Parts of this Publication:"]/following-sibling::a').map do |r|
          { type: 'partOf', identifier: r.text, url: DOMAIN + r[:href] }
        end

        doc.xpath('//strong[text()="Related NIST Publications:"]/following-sibling::a').map do |r|
          relations << { type: 'updates', identifier: r.text, url: DOMAIN + r[:href] }
        end

        relations
      end
    end
  end
end