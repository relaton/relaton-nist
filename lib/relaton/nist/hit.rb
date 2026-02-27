# frozen_string_literal: true

module Relaton
  module Nist
    class Hit < Core::Hit
      attr_writer :item

      #
      # Parse page.
      #
      # @return [Relaton::Nist::ItemData] bibliographic item
      #
      def item
        @item ||= Scraper.parse_page @hit
      end
    end
  end
end
