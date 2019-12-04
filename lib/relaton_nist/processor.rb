require "relaton/processor"

module RelatonNist
  class Processor < Relaton::Processor
    def initialize
      @short = :relaton_nist
      @prefix = "NIST"
      @defaultprefix = %r{^(NIST|NISTGCR|ITL Bulletin|JPCRD|NISTIR|CSRC|FIPS)(/[^\s])?\s}
      @idtype = "NIST"
    end

    # @param code [String]
    # @param date [String, NilClass] year
    # @param opts [Hash]
    # @return [RelatonNist::GbBibliographicItem]
    def get(code, date = nil, opts = {})
      ::RelatonNist::NistBibliography.get(code, date, opts)
    end

    # @param xml [String]
    # @return [RelatonNist::GbBibliographicItem]
    def from_xml(xml)
      ::RelatonNist::XMLParser.from_xml xml
    end

    # @param hash [Hash]
    # @return [RelatonNist::GbBibliographicItem]
    def hash_to_bib(hash)
      item_hash = ::RelatonNist::HashConverter.hash_to_bib(hash)
      ::RelatonNist::NistBibliographicItem.new item_hash
    end

    # Returns hash of XML grammar
    # @return [String]
    def grammar_hash
      @grammar_hash ||= ::RelatonNist.grammar_hash
    end
  end
end
