require "relaton_nist/version"
require "relaton_nist/nist_bibliography"

# if defined? Relaton
#   require_relative "relaton/processor"
#   Relaton::Registry.instance.register(Relaton::RelatonNist::Processor)
# end

module RelatonNist
  class Error < StandardError; end
end
