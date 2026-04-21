require_relative "doctype"
require_relative "comment_period"

module Relaton
  module Nist
    class Ext < Bib::Ext
      attribute :doctype, Doctype
      attribute :commentperiod, CommentPeriod

      xml { map_element "commentperiod", to: :commentperiod }
      key_value { map_element "commentperiod", to: :commentperiod }

      def get_schema_version = Relaton.schema_versions["relaton-model-nist"]
    end
  end
end
