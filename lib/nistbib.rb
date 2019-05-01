require "nistbib/version"
require "nistbib/nist_bibliography"

if defined? Relaton
  require_relative "relaton/processor"
  Relaton::Registry.instance.register(Relaton::NistBib::Processor)
end

module NistBib
  class Error < StandardError; end
  # Your code goes here...
end
