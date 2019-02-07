require "relaton/processor"

module Relaton
  module Isobib
    class Processor < Relaton::Processor

      def initialize
        @short = :nistbib
        @prefix = "NIST"
        @defaultprefix = %r{^(NIST)[ /]}
        @idtype = "NIST"
      end

      def get(code, date, opts)
        ::Nistbib::NistBibliography.get(code, date, opts)
      end

      def from_xml(xml)
        IsoBibItem::XMLParser.from_xml xml
      end
    end
  end
end
