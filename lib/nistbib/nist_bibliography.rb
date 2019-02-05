require 'nistbib/scrapper'
require 'nistbib/hit_collection'

module NistBib
  class NistBibliography
    class << self
      def search(text, year = nil)
        HitCollection.new text, year
      rescue
        warn "Could not access https://www.nist.gov"
        []       
      end

      def get(code, year, opts)
        search(code)
      end
    end
  end
end