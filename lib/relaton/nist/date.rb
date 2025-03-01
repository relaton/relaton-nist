module Relaton
  module Nist
    class Date < Bib::Date
      attribute :type, :string, values: %w[abandoned superseded]
    end
  end
end
