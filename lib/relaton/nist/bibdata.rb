module Relaton
  module Nist
    class Bibdata < Item
      model ItemData
      include Bib::BibdataShared
    end
  end
end
