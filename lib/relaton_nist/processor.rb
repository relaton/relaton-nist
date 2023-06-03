require "relaton/processor"

module RelatonNist
  class Processor < Relaton::Processor
    def initialize # rubocop:disable Lint/MissingSuper
      @short = :relaton_nist
      @prefix = "NIST"
      @defaultprefix = %r{^(NIST|NBS|NISTGCR|ITL Bulletin|JPCRD|NISTIR|CSRC|FIPS)(/[^\s])?\s}
      @idtype = "NIST"
      @datasets = %w[nist-tech-pubs]
    end

    # @param code [String]
    # @param date [String, NilClass] year
    # @param opts [Hash]
    # @return [RelatonNist::GbBibliographicItem]
    def get(code, date = nil, opts = {})
      ::RelatonNist::NistBibliography.get(code, date, opts)
    end

    #
    # Fetch all the documents from a source
    #
    # @param [String] _source source name
    # @param [Hash] opts
    # @option opts [String] :output directory to output documents
    # @option opts [String] :format
    #
    def fetch_data(_source, opts)
      DataFetcher.fetch(**opts)
    end

    # @param xml [String]
    # @return [RelatonNist::GbBibliographicItem]
    def from_xml(xml)
      ::RelatonNist::XMLParser.from_xml xml
    end

    # @param hash [Hash]
    # @return [RelatonNist::GbBibliographicItem]
    def hash_to_bib(hash)
      ::RelatonNist::NistBibliographicItem.from_hash hash
    end

    # Returns hash of XML grammar
    # @return [String]
    def grammar_hash
      @grammar_hash ||= ::RelatonNist.grammar_hash
    end

    #
    # Remove index file
    #
    def remove_index_file
      Relaton::Index.find_or_create(:nist, url: true, file: HitCollection::INDEX_FILE).remove_file
    end
  end
end
