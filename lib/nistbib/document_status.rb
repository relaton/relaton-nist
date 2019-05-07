module NistBib
  class DocumentStatus
    STAGES = %w[
      draft-internal draft-wip draft-prelim draft-public final final-review
    ].freeze

    SUBSTAGES = %w[active retired withdrawn].freeze

    # @return [String]
    attr_reader :stage

    # @return [String, NilClass]
    attr_reader :substage

    # @return [String, NilClass]
    attr_reader :iteration

    # @param stage [String]
    # @param substage [String, NilClass]
    # @param iteration [String, NilClass]
    def initialize(stage:, substage: nil, iteration: nil)
      unless STAGES.include? stage
        raise ArgumentError, "invalid argument: stage (#{stage})"
      end

      if substage && !SUBSTAGES.include?(substage)
        raise ArgumentError, "invalid argument: substage (#{substage})"
      end

      @stage = stage
      @substage = substage
      @iteration = iteration
    end

    # @param builder [Nokogiri::XML::Builder]
    def to_xml(builder)
      builder.status do
        builder.stage stage
        builder.substage substage if substage
        builder.iteration iteration if iteration
      end
    end
  end
end
