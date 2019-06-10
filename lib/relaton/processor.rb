require "relaton/processor"

module Relaton
  module RelatonNist
    class Processor < Relaton::Processor

      def initialize
        @short = :relaton_nist
        @prefix = "NIST"
        @defaultprefix = %r{^(NIST|NISTGCR|ITL Bulletin|JPCRD|NISTIR|CSRC|FIPS|SP)[ /]}
        @idtype = "NIST"
      end

      def get(code, date = nil, opts = {})
        ::RelatonNist::NistBibliography.get(code, date, opts)
      end

      def from_xml(xml)
        ::RelatonNist::XMLParser.from_xml xml
      end
    end
  end
end
