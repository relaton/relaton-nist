# frozen_string_literal: true

module NistBib
  # Hit.
  class Hit
    # @return [Isobib::HitCollection]
    attr_reader :hit_collection

    # @return [Array<Hash>]
    attr_reader :hit

    # @param hit [Hash]
    # @param hit_collection [Isobib:HitCollection]
    def initialize(hit, hit_collection = nil)
      @hit            = hit
      @hit_collection = hit_collection
    end

    # Parse page.
    # @return [Isobib::IsoBibliographicItem]
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
    def to_xml(opts = {})
      #if builder
        #fetch.to_xml builder, opts
      #else
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          fetch.to_xml xml, opts
        end
        builder.doc.root.to_xml
      #end
    end
  end
end
