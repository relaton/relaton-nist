module RelatonNist
  module HashConverter
    include RelatonBib::HashConverter
    extend self

    # @override RelatonBib::HashConverter.hash_to_bib
    # @param args [Hash]
    # @param nested [TrueClass, FalseClass]
    # @return [Hash]
    def hash_to_bib(args)
      ret = super
      return if ret.nil?

      commentperiod_hash_to_bib(ret)
      ret
    end

    private

    # @param item_hash [Hash]
    # @return [RelatonNist::NistBibliographicItem]
    def bib_item(item_hash)
      NistBibliographicItem.new(**item_hash)
    end

    def commentperiod_hash_to_bib(ret)
      cp = ret.dig(:ext, :commentperiod) || ret[:commentperiod] # @TODO: remove ret[:commentperiod] after all gem versions are updated
      return unless cp

      ret[:commentperiod] = CommentPeriod.new(**cp)
    end

    # @param ret [Hash]
    def relations_hash_to_bib(ret)
      super
      return unless ret[:relation]

      ret[:relation] = ret[:relation].map { |r| DocumentRelation.new(**r) }

      # ret[:relation] = array(ret[:relation])
      # ret[:relation]&.each do |r|
      #   if r[:description]
      #     r[:description] = FormattedString.new r[:description]
      #   end
      #   relation_bibitem_hash_to_bib(r)
      #   relation_locality_hash_to_bib(r)
      #   relation_source_locality_hash_to_bib(r)
      # end
    end
  end
end
