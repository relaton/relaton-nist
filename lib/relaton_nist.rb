require "singleton"
require "pubid"
require "relaton/index"
require "relaton_bib"
require "relaton_nist/version"
require "relaton_nist/util"
# require "relaton_nist/pubid"
require "relaton_nist/nist_bibliography"
require "relaton_nist/data_fetcher"
require "relaton_nist/pubs_export"
require "relaton_nist/tech_pubs_parser"

# if defined? Relaton
#   require_relative "relaton/processor"
#   Relaton::Registry.instance.register(Relaton::RelatonNist::Processor)
# end

module RelatonNist
  class Error < StandardError; end

  # Returns hash of XML reammar
  # @return [String]
  def self.grammar_hash
    # gem_path = File.expand_path "..", __dir__
    # grammars_path = File.join gem_path, "grammars", "*"
    # grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
    Digest::MD5.hexdigest RelatonNist::VERSION + RelatonBib::VERSION # grammars
  end
end
