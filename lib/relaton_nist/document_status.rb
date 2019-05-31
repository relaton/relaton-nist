module RelatonNist
  class DocumentStatus < RelatonBib::DocumentStatus
    STAGES = %w[
      draft-internal draft-wip draft-prelim draft-public final final-review
    ].freeze

    SUBSTAGES = %w[active retired withdrawn].freeze

    # @param stage [String]
    # @param substage [String, NilClass]
    # @param iteration [String, NilClass]
    def initialize(stage:, substage: nil, iteration: nil)
      # unless STAGES.include? stage
      #   raise ArgumentError, "invalid argument: stage (#{stage})"
      # end

      # if substage && !SUBSTAGES.include?(substage)
      #   raise ArgumentError, "invalid argument: substage (#{substage})"
      # end

      super
    end
  end
end
