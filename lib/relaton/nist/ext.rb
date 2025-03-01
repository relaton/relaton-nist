require_relative "doctype"
require_relative "editorial_group"
require_relative "comment_period"

module Relaton
  module Nist
    class Ext < Lutaml::Model::Serializable
      attribute :schema_version, :string
      attribute :doctype, Doctype
      attribute :subdoctype, :string
      attribute :flavor, :string
      attribute :editorialgroup, EditorialGroup
      attribute :ics, Bib::ICS, collection: true
      attribute :commentperiod, CommentPeriod

      xml do
        map_attribute "schema-version", to: :schema_version
        map_element "doctype", to: :doctype
        map_element "subdoctype", to: :subdoctype
        map_element "flavor", to: :flavor
        map_element "editorialgroup", to: :editorialgroup
        map_element "ics", to: :ics
        map_element "commentperiod", to: :commentperiod
      end
    end
  end
end
