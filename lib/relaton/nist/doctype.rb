module Relaton
  module Nist
    class Doctype < Bib::Doctype
      attribute :content, :string, values: %w[standard]
    end
  end
end
