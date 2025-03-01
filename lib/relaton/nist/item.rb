require_relative "date"
require_relative "ext"

module Relaton
  module Nist
    class Relation < Bib::Relation
    end

    class Item < Bib::Item
      model Bib::ItemData

      attribute :date, Date, collection: true
      attribute :relation, Relation, collection: true
      attribute :ext, Ext
    end
  end
end
