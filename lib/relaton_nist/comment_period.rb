module RelatonNist
  class CommentPeriod
    # @return [Date]
    attr_reader :from

    # @rerurn [Date, NilClass]
    attr_reader :to

    # @return [Date, NilClass]
    attr_reader :extended

    # @param from [Date]
    # @param to [Date, NilClass]
    # @param extended [Date, NilClass]
    def initialize(from:, to: nil, extended: nil)
      @from = from
      @to = to
      @extended = extended
    end

    # @param [Nokogiri::XML::Builder]
    def to_xml(builder)
      builder.commentperiod do
        builder.from from.to_s
        builder.to to.to_s if to
        builder.extended extended.to_s if extended
      end
    end

    # @return [Hash]
    def to_hash
      hash = { "from" => from.to_s }
      hash["to"] = to.to_s if to
      hash["extended"] = extended.to_s if extended
      hash
    end
  end
end
