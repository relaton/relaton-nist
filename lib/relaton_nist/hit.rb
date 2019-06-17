# frozen_string_literal: true

module RelatonNist
  # Hit.
  class Hit
    # @return [RelatonNist::HitCollection]
    attr_reader :hit_collection

    # @return [Array<Hash>]
    attr_reader :hit

    # @param hit [Hash]
    # @param hit_collection [RelatonNist:HitCollection]
    def initialize(hit, hit_collection = nil)
      @hit            = hit
      @hit_collection = hit_collection
    end

    # Parse page.
    # @return [RelatonNist::NistBliographicItem]
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
      @sort_value ||= begin
        sort_phrase = [hit[:serie], hit[:code], hit[:title]].join " "
        corr = hit_collection.text.split.map do |w|
          if w =~ /\w+/ &&
              sort_phrase =~ Regexp.new(Regexp.escape(w), Regexp::IGNORECASE)
            1
          else 0
          end
        end.sum
        corr + case hit[:status]
               when "final" then 3
               when "withdrawn" then 2
               when "draft (withdrawn)" then 1
               else 0
               end
      end
    end
  end
end
