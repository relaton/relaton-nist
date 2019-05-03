module NistBib
  class XMLParser < RelatonBib::XMLParser
    class << self
      def from_xml(xml)
        doc = Nokogiri::XML xml
        nistitem = doc.at "/nist-standard"
        NistBibliographicItem.new(item_data(nistitem))
      end

      private

      def item_data(nistitem)
        data = super
        data.delete :id
        data.delete :series
        data[:nistseries] = fetch_nistseries(nistitem)
        data[:keyword] = fetch_keyword(nistitem)
        data[:commentperiod] = fetch_commentperiod(nistitem)
        data
      end

      def fetch_commentperiod(item)
        cp = item.at "./commentperiod"
        return unless cp

        CommentPeriod.new cp.at("from").text, cp.at("to")&.text, cp.at("extended")&.text
      end

      def fetch_keyword(item)
        item.xpath("./keyword").map do |kw|
          Keyword.new kw.children.first.to_xml
        end
      end

      def fetch_nistseries(item)
        series = item.at "./series"
        return unless series

        NistSeries.new series.at("./abbreviation").text.upcase.gsub("-", " ")
      end
    end
  end
end
