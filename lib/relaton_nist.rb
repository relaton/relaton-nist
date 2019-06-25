require "relaton_nist/version"
require "relaton_nist/nist_bibliography"

if defined? Relaton
  require_relative "relaton/processor"
  Relaton::Registry.instance.register(Relaton::RelatonNist::Processor)
end

module RelatonNist
  class Error < StandardError; end

  class << self
    # @param date [String]
    # @return [Date, NilClass]
    def parse_date(sdate)
      if /(?<date>\w+\s\d{4})/ =~ sdate # February 2012
        Date.strptime(date, "%B %Y")
      elsif /(?<date>\w+\s\d{1,2},\s\d{4})/ =~ sdate # February 11, 2012
        Date.strptime(date, "%B %d, %Y")
      elsif /(?<date>\d{4}-\d{2}-\d{2})/ =~ sdate # 2012-02-11
        Date.parse(date)
      elsif /(?<date>\d{4}-\d{2})/ =~ sdate # 2012-02
        Date.strptime date, "%Y-%m"
      end
    end
  end
end
