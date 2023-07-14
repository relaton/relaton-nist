# frozen_string_literal: true

module RelatonNist
  # Hit.
  class Hit < RelatonBib::Hit
    attr_writer :fetch

    #
    # Parse page.
    #
    # @return [RelatonNist::NistBliographicItem] bibliographic item
    #
    def fetch
      @fetch ||= Scrapper.parse_page @hit
    end

    #
    # Calculate sorting weigth of hit by series, code, title, addendum, and status
    #
    # @return [Iteger] sorting weigth
    #
    # def sort_value # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
    #   @sort_value ||= begin
    #     sort_phrase = [hit[:series], hit[:code]].join " "
    #     corr = hit_collection&.text&.split&.map do |w|
    #       if w =~ /\w+/ &&
    #           sort_phrase =~ Regexp.new(Regexp.escape(w), Regexp::IGNORECASE)
    #         1
    #       else 0
    #       end
    #     end&.sum.to_i
    #     corr + case hit[:status]
    #            when "final" then 4
    #            when "withdrawn" then 3
    #            when "draft" then 2
    #            when "draft (obsolete)" then 1
    #            else 0
    #            end
    #   end
    # end
  end
end
