module Relaton
  module Nist
    class CommentPeriod < Lutaml::Model::Serializable
      attribute :from, :date
      attribute :to, :date
      attribute :extended, :date

      xml do
        map_element "from", to: :from
        map_element "to", to: :to
        map_element "extended", to: :extended
      end
    end
  end
end
