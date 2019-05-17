module NistBib
  class XMLParser < RelatonBib::XMLParser
    class << self
      def from_xml(xml)
        doc = Nokogiri::XML xml
        nistitem = doc.at("/bibitem|/bibdata")
        NistBibliographicItem.new(item_data(nistitem))
      end

      private

      def item_data(nistitem)
        data = super
        ext = nistitem.at "./ext"
        return data unless ext

        data[:keyword] = fetch_keyword(ext)
        data[:commentperiod] = fetch_commentperiod(ext)
        data
      end

      def fetch_status(item)
        status = item.at "./status"
        return unless status

        DocumentStatus.new(
          stage: status.at("stage")&.text,
          substage: status.at("substage")&.text,
          iteration: status.at("iteration")&.text,
        )
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
    end
  end
end
