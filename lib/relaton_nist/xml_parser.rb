module RelatonNist
  class XMLParser < RelatonBib::XMLParser
    class << self
      private

      # @param intem [Nokogiri::XML::Document]
      # @return [Hash]
      def item_data(item)
        data = super
        ext = item.at "./ext"
        return data unless ext

        data[:commentperiod] = fetch_commentperiod(ext)
        data
      end

      # @param item_hash [Hash]
      # @return [RelatonNist::NistBibliographicItem]
      def bib_item(item_hash)
        NistBibliographicItem.new(**item_hash)
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

        CommentPeriod.new(
          from: cp.at("from").text, to: cp.at("to")&.text,
          extended: cp.at("extended")&.text
        )
      end

      # @param item [Nokogiri::XML::Element]
      # @return [Array<RelatonBib::DocumentRelation>]
      def fetch_relations(item)
        super item, DocumentRelation
      end
    end
  end
end
