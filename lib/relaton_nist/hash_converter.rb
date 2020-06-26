module RelatonNist
  class HashConverter < RelatonBib::HashConverter
    class << self
      # @override RelatonBib::HashConverter.hash_to_bib
      # @param args [Hash]
      # @param nested [TrueClass, FalseClass]
      # @return [Hash]
      def hash_to_bib(args, nested = false)
        ret = super
        return if ret.nil?

        commentperiod_hash_to_bib(ret)
        ret
      end

      private

      # @param item_hash [Hash]
      # @return [RelatonNist::NistBibliographicItem]
      def bib_item(item_hash)
        NistBibliographicItem.new item_hash
      end

      def commentperiod_hash_to_bib(ret)
        return unless ret[:commentperiod]

        ret[:commentperiod] = CommentPeriod.new ret[:commentperiod]
      end
    end
  end
end
