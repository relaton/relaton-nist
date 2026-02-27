require "pubid"
require "relaton/index"
require "relaton/bib"
require_relative "nist/version"
require_relative "nist/util"
require_relative "nist/item_data"
require_relative "nist/item"
require_relative "nist/relation"
require_relative "nist/bibitem"
require_relative "nist/bibdata"
require_relative "nist/pubs_export"
require_relative "nist/hit"
require_relative "nist/hit_collection"
require_relative "nist/scraper"
require_relative "nist/bibliography"
# require_relative "nist/tech_pubs_parser"

module Relaton
  module Nist
    INDEXFILE = "index-v1"

    class Error < StandardError; end

    # Returns hash of XML grammar
    # @return [String]
    def self.grammar_hash
      Digest::MD5.hexdigest Relaton::Nist::VERSION + Relaton::Bib::VERSION
    end
  end
end
