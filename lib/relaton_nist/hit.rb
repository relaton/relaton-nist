# frozen_string_literal: true

module RelatonNist
  # Hit.
  class Hit < RelatonBib::Hit
    # @return [RelatonNist::HitCollection]
    attr_reader :hit_collection

    # Parse page.
    # @return [RelatonNist::NistBliographicItem]
    def fetch
      @fetch ||= Scrapper.parse_page @hit
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
