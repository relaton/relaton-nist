# frozen_string_literal: true

require "zip"
require "fileutils"
require "addressable/uri"
require "net/http"

module Relaton
  module Nist
    class HitCollection < Core::HitCollection
      include Core::DateParser

      GHNISTDATA = "https://raw.githubusercontent.com/relaton/relaton-data-nist/data-v2/"

      attr_reader :reference
      attr_accessor :array

      #
      # @param [String] ref reference
      # @param [String, nil] year reference
      # @param [Hash] opts options
      # @option opts [String] :stage stage of document
      #
      def initialize(ref, year = nil, opts = {})
        super(ref, year)
        @reference = ref
        @opts = opts
      end

      #
      # Create hits collection instance and search hits
      #
      # @param [String] ref reference
      # @param [String, nil] year reference
      # @param [Hash] opts options
      # @option opts [String] :stage stage of document
      #
      # @return [Relaton::Nist::HitCollection] hits collection
      #
      def self.search(ref, year = nil, opts = {})
        new(ref, year, opts).search
      end

      #
      # Search nist in JSON file or GitHub repo
      #
      # @return [Relaton::Nist::HitCollection] hits collection
      #
      def search
        @array = from_json
        @array = from_ga unless @array.any?
        sort_hits!
      end

      #
      # Filter hits by reference's parts
      #
      # @return [Array<Relaton::Nist::Hit>] hits
      #
      def search_filter # rubocop:disable Metrics/MethodLength
        refid = ::Pubid::Nist::Identifier.parse(@reference)
        parts = exclude_parts refid
        arr = @array.select do |item|
          pubid = ::Pubid::Nist::Identifier.parse(item.hit[:code].sub(/\.$/, ""))
          pubid.exclude(*parts) == refid
        rescue StandardError
          item.hit[:code] == ref
        end
      rescue StandardError
        arr = @array.select { |item| item.hit[:code] == ref }
      ensure
        dup = self.dup
        dup.array = arr
        return dup
      end

      def exclude_parts(pubid)
        %i[stage update].each_with_object([]) do |part, parts|
          parts << part if pubid.send(part).nil?
        end
      end

      private

      def code_parts(code) # rubocop:disable Metrics/MethodLength
        {
          series: match(/(?<val>(?:SP|FIPS|CSWP|IR|ITL\sBulletin|White\sPaper))\s/, code),
          code: match(/(?<val>[0-9-]+(?:(?!(?:ver|r|v|pt)\d|-add\d?)[A-Za-z-])*|Research\sLibrary)/, code),
          prt: match(/(?:pt|\sPart\s)(?<val>\d+)/, code),
          vol: match(/(?:v|\sVol\.\s)(?<val>\d+)/, code),
          ver: match(/(?:ver|\sVer\.\s|Version\s)(?<val>[\d.]+)/, code),
          rev: match(/(?:r|Rev\.\s)(?<val>\d+)/, code),
          add: match(/(?:-add|\sAdd)(?:endum)?(?<val>\d*)/, code),
          draft: !match(/\((?:Retired\s)?Draft\)/, code).nil?,
        }
      end

      def doi_parts(json) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        return unless json && json["doi"]

        id = json["doi"].split("/").last
        {
          series: match(/(?:SP|FIPS|CSWP|IR|ITL\sBulletin|White\sPaper)(?=\.)/, id),
          code: match(/(?<=\.)\d+(?:-\d+)*(?:[[:alpha:]](?!\d|raft|er|t?\d))?/, id),
          prt: match(/pt?(?<val>\d+)/, id),
          vol: match(/v(?<val>\d+)(?!\.\d)/, id),
          ver: match(/v(?:er)?(?<val>[\d.]+)/, id),
          rev: match(/r(?<val>\d+)/, id),
          add: match(/-Add(?<val>\d*)/, id),
          draft: !match(/\.ipd|-draft/, id).nil?,
        }
      end

      #
      # Parse reference parts
      #
      # @return [Hash] reference parts
      #
      def refparts # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        @refparts ||= {
          perfix: match(/^(NIST|NBS)/, ref),
          series: match(/(SP|FIPS|CSWP|IR|ITL\sBulletin|White\sPaper)(?=\.|\s)/, ref),
          code: match(/(?<=\.|\s)[0-9-]+(?:(?!(ver|r|v|pt)\d|-add\d?)[A-Za-z-])*|Research\sLibrary/, ref),
          prt: match(/(?:(?<dl>\.)?pt(?(<dl>)-)|\sPart\s)(?<val>[A-Z\d]+)/, ref),
          vol: match(/(?:(?<dl>\.)?v(?(<dl>)-)|\sVol\.\s)(?<val>\d+)/, ref),
          ver: match(/(?:(?<dl>\.)?\s?ver|\sVer\.\s)(?<val>\d(?(<dl>)[-\d]|[.\d])*)/, ref)&.gsub(/-/, "."),
          rev: match(/(?:(?:(?<dl>\.)|[^a-z])r|\sRev\.\s)(?(<dl>)-)(?<val>\d+)/, ref),
          add: match(/(?:(?<dl>\.)?add|\/Add|\sAdd)(?(<dl>)-)(?<val>\d*)/, ref),
          draft: !(match(/\((?:Draft|PD)\)/, ref).nil? && @opts[:stage].nil?),
        }
      end

      #
      # Match regex to reference
      #
      # @param [Regexp] regex regex
      # @param [String] code reference
      #
      # @return [String, nil] matched string
      #
      def match(regex, code)
        m = regex.match(code)
        return unless m

        m.named_captures["val"] || m.to_s
      end

      #
      # Generate reference from parts
      #
      # @return [String] reference
      #
      def full_ref # rubocop:disable Metrics/AbcSize
        @full_ref ||= begin
          r = [refparts[:perfix], refparts[:series], refparts[:code]].compact.join " "
          r += "pt#{refparts[:prt]}" if refparts[:prt]
          r += "ver#{refparts[:ver]}" if refparts[:ver]
          r += "v#{refparts[:vol]}" if refparts[:vol]
          r += "r#{refparts[:rev]}" if refparts[:rev]
          r += "-add#{refparts[:add]}" if refparts[:add]
          r
        end
      end

      #
      # Sort hits by sort_value and release date
      #
      # @return [self] sorted hits collection
      #
      def sort_hits!
        @array.sort! do |a, b|
          code = a.hit[:code] <=> b.hit[:code]
          next code unless code.zero?

          b.hit[:release_date] <=> a.hit[:release_date]
        end
        self
      end

      def pubid(id = ref)
        Pubid::Nist::Identifier.parse(id).to_s
      rescue StandardError
        id
      end

      #
      # Get hit from GitHub repo
      #
      # @return [Array<Relaton::Nist::Hit>] hits
      #
      def from_ga # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        Util.info "Fetching from Relaton repository ...", key: @reference
        r = pubid

        index = Relaton::Index.find_or_create :nist, url: "#{GHNISTDATA}index-v1.zip", file: "#{INDEXFILE}.yaml"
        rows = index.search(r).sort_by { |row| row[:id] }

        rows.map do |row|
          Hit.new({ code: row[:id], path: row[:file] }, self)
        end
      rescue OpenURI::HTTPError => e
        return [] if e.io.status[0] == "404"

        raise e
      end

      #
      # Fetches data from json
      #
      # @return [Array<Relaton::Nist::Hit>] hits
      #
      def from_json # rubocop:disable Metrics/AbcSize
        Util.info "Fetching from csrc.nist.gov ...", key: @reference
        select_data.map do |h|
          /(?<series>(?<=-)\w+$)/ =~ h["series"]
          title = [h["title-main"], h["title-sub"]].compact.join " - "
          release_date = parse_date(h["published-date"], str: false)
          Hit.new({ code: pubs_export_id(h), series: series.upcase, title: title, url: h["uri"],
                    status: h["status"], release_date: release_date, json: h }, self)
        end
      end

      def pubs_export_id(json) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
        if json && json["doi"]
          json["doi"].sub(/^10.6028\//, "")
        else
          json["docidentifier"]
        end => id

        id.sub!(/(?:-draft\d*|\.\wpd)$/, "")
        id = id.gsub(".", " ").sub(/-Add(\d*)$/, ' Add\1') if id.match?(/-Add\d*$/)
        pid = ::Pubid::Nist::Identifier.parse(id)
        case json["iteration"]
        when "final"
          pid.stage = ::Pubid::Nist::Stage.new id: "f", type: "pd"
        when "fpd"
          pid.stage = ::Pubid::Nist::Stage.new id: "f", type: "pd"
        when /(\w)pd/
          pid.stage = ::Pubid::Nist::Stage.new id: Regexp.last_match(1), type: "pd"
        end

        /\/upd(?<upd>\d+)\// =~ json["uri"]
        pid.update = Pubid::Nist::Update.new number: upd if upd
        pid.to_s
      rescue StandardError
        id += " #{json["iteration"].sub('final', 'fpd')}" if json["iteration"]
        id
      end

      #
      # Select data from json
      #
      # @return [Array<Hash>] selected data
      #
      def select_data # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength,Metrics/PerceivedComplexity
        return [] unless refparts[:code]

        r = "#{refparts[:series]} #{refparts[:code]}"
        d = parse_date(year, str: false) if year
        PubsExport.instance.data.select do |doc|
          next unless match_year?(doc, d)

          doc["docidentifier"].include?(r) || doc["docidentifier"].include?(full_ref)
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
        pidate = parse_date(d, str: false)
        pidate.between? date, date.next_year.prev_day
      rescue ::Date::Error, TypeError
        false
      end
    end
  end
end
