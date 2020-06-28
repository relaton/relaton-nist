module RelatonNist
  class DocumentRelation < RelatonBib::DocumentRelation
    TYPES += %w[obsoletedBy supersedes supersededBy].freeze
  end
end
