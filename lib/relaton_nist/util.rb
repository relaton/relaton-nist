module RelatonNist
  module Util
    extend RelatonBib::Util

    def self.logger
      RelatonNist.configuration.logger
    end
  end
end
