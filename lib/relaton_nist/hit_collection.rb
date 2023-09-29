# frozen_string_literal: true

require "zip"
require "fileutils"
require "relaton_nist/hit"
require "addressable/uri"
require "open-uri"

module RelatonNist
  # Hit collection.
  class HitCollection < RelatonBib::HitCollection
    GHNISTDATA = "https://raw.githubusercontent.com/relaton/relaton-data-nist/main/"
    INDEX_FILE = "index-v1.yaml"

    #
    # @param [String] text reference
    # @param [String, nil] year reference
    # @param [Hash] opts options
    # @option opts [String] :stage stage of document
    #
    def initialize(pubid_ref, year = nil, opts = {})
      super pubid_ref.to_s, year
      @pubid_ref = pubid_ref
      @opts = opts
    end

    #
    # Create hits collection instance and search hits
    #
    # @param [String] text reference
    # @param [String, nil] year reference
    # @param [Hash] opts options
    # @option opts [String] :stage stage of document
    #
    # @return [RelatonNist::HitCollection] hits collection
    #
    def self.search(pubid_ref, year, opts = {})
      new(pubid_ref, year, opts).search
    end

    #
    # Search nits in JSON file or GitHub repo
    #
    # @return [RelatonNist::HitCollection] hits collection
    #
    def search
      @array = from_json
      @array = from_ga unless @array.any?
      sort_hits!
    end

    #
    # Filter hits by reference's parts
    #
    # @return [Array<RelatonNist::Hit>] hits
    #
    def search_filter # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/MethodLength
      @array.select do |item|
        pubid = item.hit[:code]
        @pubid_ref.serie.serie == pubid.serie.serie &&
          @pubid_ref.code == pubid.code &&
          @pubid_ref.part == pubid.part &&
          @pubid_ref.volume == pubid.volume &&
          (@pubid_ref.revision.nil? || @pubid_ref.revision == pubid.revision) &&
          @pubid_ref.edition == pubid.edition &&
          @pubid_ref.version == pubid.version &&
          @pubid_ref.supplement == pubid.supplement &&
          @pubid_ref.index == pubid.index &&
          @pubid_ref.insert == pubid.insert &&
          @pubid_ref.errata == pubid.errata &&
          @pubid_ref.appendix == pubid.appendix &&
          addendum_match?(pubid.addendum) &&
          (@pubid_ref.stage.nil? || @pubid_ref.stage.id == pubid.stage&.id) &&
          @pubid_ref.translation == pubid.translation &&
          update_match?(pubid.update)
      end
    end

    private

    def addendum_match?(addendum)
      return @pubid_ref.addendum == addendum if @pubid_ref.addendum.nil?

      @pubid_ref.addendum.upcase.sub(/\.\s?$/, "").sub(/^-/, "") == addendum&.upcase
    end

    def update_match?(update)
      return @pubid_ref.update == update if @pubid_ref.update.nil?

      @pubid_ref.update.number == update&.number && @pubid_ref.update.year == update&.year
    end

    #
    # Sort hits by sort_value and release date
    #
    # @return [self] sorted hits collection
    #
    def sort_hits!
      @array.sort! do |a, b|
        code = a.hit[:code].to_s <=> b.hit[:code].to_s
        next code unless code.zero?

        b.hit[:release_date] <=> a.hit[:release_date]
      end
      self
    end

    #
    # Get hit from GitHub repo
    #
    # @return [Array<RelatonNist::Hit>] hits
    #
    # @raise [OpenURI::HTTPError] if GitHub repo is not available
    #
    def from_ga # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      ref = @pubid_ref.to_s.sub(" Add.", "-add")
      # fn = ref.gsub(%r{[/\s:.]}, "_").upcase
      index = Relaton::Index.find_or_create :nist, url: "#{GHNISTDATA}index-v1.zip", file: INDEX_FILE
      rows = index.search { |r| r[:id].upcase.include?(ref.upcase) }.sort_by { |r| r[:id] }
      # return [] unless row

      # yaml = OpenURI.open_uri "#{GHNISTDATA}#{row[:file]}"
      # hash = YAML.safe_load yaml
      # hash["fetched"] = Date.today.to_s
      # bib = RelatonNist::NistBibliographicItem.from_hash hash
      # id = bib.docidentifier.find(&:primary).id

      rows.map do |row|
        pubid = Pubid::Nist::Identifier.parse row[:id]
        Hit.new({ code: pubid, path: row[:file] }, self)
      end
      # hit.fetch = bib
      # [hit]
    rescue OpenURI::HTTPError => e
      return [] if e.io.status[0] == "404"

      raise e
    end

    #
    # Fetches data form json
    #
    # @return [Array<RelatonNist::Hit>] hits
    #
    def from_json # rubocop:disable Metrics/AbcSize
      return [] unless @pubid_ref.serie.serie.match?(/^(NIST\s(SP|CSWP)|FIPS)/)

      select_data.map do |h|
        /(?<series>(?<=-)\w+$)/ =~ h["series"]
        title = [h["title-main"], h["title-sub"]].compact.join " - "
        release_date = RelatonBib.parse_date h["published-date"], false
        Hit.new({ code: json_pubid(h), series: series.upcase, title: title, url: h["uri"],
                  status: h["status"], release_date: release_date, json: h }, self)
      end
    end

    def json_pubid(json)
      if json["doi"]
        id = json["doi"].split("/").last.sub(/-draft\d*/, "").sub(/\.\wpd/, "").sub(/-(Add\d*)/, "")
        add = Regexp.last_match(1)
        id.sub!(/-upd(\d)/, "")
        upd = Regexp.last_match(1)
        pubid = Pubid::Nist::Identifier.parse id
        pubid.addendum = add if add
      else
        id = json["docidentifier"]
        id = "NIST #{id}" unless id.start_with? "FIPS"
        upd = json["uri"]&.match(/\/upd(\d)\//)&.captures&.first
        pubid = Pubid::Nist::Identifier.parse id
        pubid.revision ||= json["revision"] if json["revision"]
        pubid.edition ||= json["edition"] if json["edition"]
        pubid.volume ||= json["volume"] if json["volume"]
      end
      pubid.stage = create_stage json["iteration"]
      pubid.update = Pubid::Nist::Update.new number: upd if defined?(upd) && upd
      pubid
    end

    def create_stage(iteration)
      return unless iteration

      id =  case iteration
            when "ipd" then "i"
            when "final" then "f"
            else iteration.match(/^\d+/)&.to_s
            end
      Pubid::Nist::Stage.new id: id, type: "pd"
    end

    #
    # Select data from json
    #
    # @return [Array<Hash>] selected data
    #
    def select_data # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength,Metrics/PerceivedComplexity
      d = Date.strptime year, "%Y" if year
      ref = "#{@pubid_ref.serie.serie.sub(/^NIST\s|\sPUB$/, '')} #{@pubid_ref.code}" # TODO: Pubid shouldn't have PUB
      PubsExport.instance.data.select do |doc|
        next unless match_year?(doc, d)

        if @pubid_ref.stage&.type == "pd"
          next unless doc["status"] == "draft-public"
        else
          next unless doc["status"] == "final"
        end
        doc["docidentifier"].include?(ref)
      end
    end

    #
    # Check if issued date is match to year
    #
    # @param doc [Hash] document's metadata
    # @param date [Date] first day of year
    #
    # @return [Boolean]
    #
    def match_year?(doc, date)
      return true unless year

      d = doc["issued-date"] || doc["published-date"]
      pidate = RelatonBib.parse_date d, false
      pidate.between? date, date.next_year.prev_day
    end
  end
end
