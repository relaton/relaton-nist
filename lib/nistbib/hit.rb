# frozen_string_literal: true

module NistBib
  # Hit.
  class Hit
    # @return [NistBib::HitCollection]
    attr_reader :hit_collection

    # @return [Array<Hash>]
    attr_reader :hit

    # @param hit [Hash]
    # @param hit_collection [NistBib:HitCollection]
    def initialize(hit, hit_collection = nil)
      @hit            = hit
      @hit_collection = hit_collection
    end

    # Parse page.
    # @return [NistBib::NistBliographicItem]
    def fetch
      @fetch ||= Scrapper.parse_page @hit
    end

    # @return [String]
    def to_s
      inspect
    end

    # @return [String]
    def inspect
      "<#{self.class}:#{format('%#.14x', object_id << 1)} "\
      "@text=\"#{@hit_collection&.text}\" "\
      "@fetched=\"#{!@fetch.nil?}\" "\
      "@fullIdentifier=\"#{@fetch&.shortref(nil)}\" "\
      "@title=\"#{@hit[:code]}\">"
    end

    # @return [String]
    def to_xml(**opts)
      fetch.to_xml **opts
    end

    # @return [Iteger]
    def sort_value
      case hit[:status]
      when "final" then 1
      when "withdrawn" then 2
      when "draft (withdrawn)" then 3
      else 4
      end
    end
  end
end
