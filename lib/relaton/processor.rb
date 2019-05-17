require "relaton/processor"

module Relaton
  module NistBib
    class Processor < Relaton::Processor

      def initialize
        @short = :nistbib
        @prefix = "NIST"
        @defaultprefix = %r{^(NIST|NISTGCR|ITL Bulletin|JPCRD|NISTIR|CSRC)[ /]}
        @idtype = "NIST"
      end

      def get(code, date = nil, opts = {})
        ::NistBib::NistBibliography.get(code, date, opts)
      end

      def from_xml(xml)
        ::NistBib::XMLParser.from_xml xml
      end
    end
  end
end
