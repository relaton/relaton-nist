module Relaton
  module Nist
    class EditorialGroup < Lutaml::Model::Serializable
      attribute :committee, :string, collection: true

      xml do
        map_element "committee", to: :committee
      end
    end
  end
end
