require "relaton/core/processor"

module Relaton
  module Nist
    class Processor < Core::Processor
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
      # @return [Relaton::Nist::ItemData]
      def get(code, date = nil, opts = {})
        require_relative "../nist"
        Bibliography.get(code, date, opts)
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
        require_relative "data_fetcher"
        DataFetcher.fetch(**opts)
      end

      # @param xml [String]
      # @return [Relaton::Nist::ItemData]
      def from_xml(xml)
        require_relative "../nist"
        Item.from_xml(xml)
      end

      # @param yaml [String]
      # @return [Relaton::Nist::ItemData]
      def from_yaml(yaml)
        require_relative "../nist"
        Item.from_yaml(yaml)
      end

      # Returns hash of XML grammar
      # @return [String]
      def grammar_hash
        require_relative "../nist"
        @grammar_hash ||= Nist.grammar_hash
      end

      #
      # Remove index file
      #
      def remove_index_file
        require_relative "../nist"
        Relaton::Index.find_or_create(:nist, url: true, file: "#{INDEXFILE}.yaml").remove_file
      end
    end
  end
end
