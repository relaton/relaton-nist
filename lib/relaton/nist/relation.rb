module Relaton
  module Nist
    class Relation
      attribute :type, :string, values: %w[obsoletedBy supersedes supersededBy]
    end
  end
end
