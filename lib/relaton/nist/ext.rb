require_relative "doctype"
require_relative "comment_period"

module Relaton
  module Nist
    class Ext < Bib::Ext
      attribute :schema_version, method: :get_schema_version
      attribute :doctype, Doctype
      attribute :commentperiod, CommentPeriod

      xml do
        map_element "commentperiod", to: :commentperiod
      end

      def get_schema_version
        Relaton.schema_versions["relaton-model-nist"]
      end
    end
  end
end
