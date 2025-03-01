require "singleton"
require "pubid"
require "relaton/index"
require "relaton/bib"
require_relative "nist/version"
require_relative "nist/util"
require_relative "nist/item"
require_relative "nist/relation"
require_relative "nist/bibitem"
require_relative "nist/bibdata"
# require "relaton_nist/pubid"
# require "relaton_nist/nist_bibliography"
# require "relaton_nist/data_fetcher"
# require "relaton_nist/pubs_export"
# require "relaton_nist/tech_pubs_parser"

# if defined? Relaton
#   require_relative "relaton/processor"
#   Relaton::Registry.instance.register(Relaton::RelatonNist::Processor)
# end

module Relaton
  module Nist
    class Error < StandardError; end

    # Returns hash of XML reammar
    # @return [String]
    def self.grammar_hash
      # gem_path = File.expand_path "..", __dir__
      # grammars_path = File.join gem_path, "grammars", "*"
      # grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
      Digest::MD5.hexdigest Relaton::Nist::VERSION + Relaton::Bib::VERSION # grammars
    end
  end
end
