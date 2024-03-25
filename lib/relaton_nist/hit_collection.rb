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

    attr_reader :reference
    attr_accessor :array

    #
    # @param [String] text reference
    # @param [String, nil] year reference
    # @param [Hash] opts options
    # @option opts [String] :stage stage of document
    #
    def initialize(text, year = nil, opts = {})
      super text, year
      @reference = year && !text.match?(/:\d{4}$/) ? "#{text}:#{year}" : text
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
    def self.search(text, year = nil, opts = {})
      new(text, year, opts).search
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
      arr = @array.select do |item|
        parts = doi_parts(item.hit[:json]) || code_parts(item.hit[:code])
        iteration = item.hit.dig(:json, "iteration")
        draft = parts[:draft] || (!iteration.nil? && iteration.match?(/\wpd/i))
        refparts[:code] && [parts[:series], item.hit[:series]].include?(refparts[:series]) &&
          refparts[:code].casecmp(parts[:code].upcase).zero? &&
          refparts[:prt] == parts[:prt] &&
          (refparts[:vol].nil? || refparts[:vol] == parts[:vol]) &&
          (refparts[:ver].nil? || refparts[:ver] == parts[:ver]) &&
          (refparts[:rev].nil? || refparts[:rev] == parts[:rev]) &&
          refparts[:draft] == draft && refparts[:add] == parts[:add]
      end
      dup = self.dup
      dup.array = arr
      dup
    end

    private

    def code_parts(code) # rubocop:disable Metrics/MethodLength
      {
        # prefix: match(/^(?:NIST|NBS)\s?/, code),
        series: match(/(?<val>(?:SP|FIPS|CSWP|IR|ITL\sBulletin|White\sPaper))\s/, code),
        code: match(/(?<val>[0-9-]+(?:(?!(?:ver|r|v|pt)\d|-add\d?)[A-Za-z-])*|Research\sLibrary)/, code),
        prt: match(/(?:pt|\sPart\s)(?<val>\d+)/, code),
        vol: match(/(?:v|\sVol\.\s)(?<val>\d+)/, code),
        ver: match(/(?:ver|\sVer\.\s|Version\s)(?<val>[\d.]+)/, code),
        rev: match(/(?:r|Rev\.\s)(?<val>\d+)/, code),
        # (?:\s(?<prt2>Part\s\d+))?
        # (?:\s(?<vol2>Vol\.\s\d+))?
        # (?:\s(?<ver2>(?:Ver\.|Version)\s[\d.]+))?
        # (?:\s(?<rev2>Rev\.\s\d+))?
        add: match(/(?:-add|\sAdd)(?:endum)?(?<val>\d*)/, code),
        draft: !match(/\((?:Retired\s)?Draft\)/, code).nil?,
      }
    end

    def doi_parts(json) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
      return unless json && json["doi"]

      id = json["doi"].split("/").last
      {
        # prefix: match(/^(?:NIST|NBS)\./, id),
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
        perfix: match(/^(NIST|NBS)/, text),
        series: match(/(SP|FIPS|CSWP|IR|ITL\sBulletin|White\sPaper)(?=\.|\s)/, text),
        code: match(/(?<=\.|\s)[0-9-]+(?:(?!(ver|r|v|pt)\d|-add\d?)[A-Za-z-])*|Research\sLibrary/, text),
        prt: match(/(?:(?<dl>\.)?pt(?(<dl>)-)|\sPart\s)(?<val>[A-Z\d]+)/, text),
        vol: match(/(?:(?<dl>\.)?v(?(<dl>)-)|\sVol\.\s)(?<val>\d+)/, text),
        ver: match(/(?:(?<dl>\.)?\s?ver|\sVer\.\s)(?<val>\d(?(<dl>)[-\d]|[.\d])*)/, text)&.gsub(/-/, "."),
        rev: match(/(?:(?:(?<dl>\.)|[^a-z])r|\sRev\.\s)(?(<dl>)-)(?<val>\d+)/, text),
        add: match(/(?:(?<dl>\.)?add|\/Add)(?(<dl>)-)(?<val>\d*)/, text),
        draft: !(match(/\((?:Draft|PD)\)/, text).nil? && @opts[:stage].nil?),
        # prt2: match(/(?<=\s)Part\s[A-Z\d]+/, text),
        # vol2: match(/(?<=\s)Vol\.\s\d+/, text),
        # ver2: match(/(?<=\s)Ver\.\s\d+/, text),
        # rev2: match(/(?<=\s)Rev\.\s\d+/, text),
        # add2: match(/(?<=\/)Add/, text),
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
        ref = [refparts[:perfix], refparts[:series], refparts[:code]].compact.join " "
        ref += "pt#{refparts[:prt]}" if refparts[:prt]
        ref += "ver#{refparts[:ver]}" if refparts[:ver]
        ref += "v#{refparts[:vol]}" if refparts[:vol]
        ref += "r#{refparts[:rev]}" if refparts[:rev]
        ref
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

    #
    # Get hit from GitHub repo
    #
    # @return [Array<RelatonNist::Hit>] hits
    #
    # @raise [OpenURI::HTTPError] if GitHub repo is not available
    #
    def from_ga # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      Util.info "Fetching from Relaton repository ...", key: @reference
      ref = full_ref
      return [] if ref.empty?

      # fn = ref.gsub(%r{[/\s:.]}, "_").upcase
      index = Relaton::Index.find_or_create :nist, url: "#{GHNISTDATA}index-v1.zip", file: INDEX_FILE
      rows = index.search(ref).sort_by { |r| r[:id] }
      # return [] unless row

      # yaml = OpenURI.open_uri "#{GHNISTDATA}#{row[:file]}"
      # hash = YAML.safe_load yaml
      # hash["fetched"] = Date.today.to_s
      # bib = RelatonNist::NistBibliographicItem.from_hash hash
      # id = bib.docidentifier.find(&:primary).id

      rows.map do |row|
        Hit.new({ code: row[:id], path: row[:file] }, self)
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
      Util.info "Fetching from csrc.nist.gov ...", key: @reference
      select_data.map do |h|
        /(?<series>(?<=-)\w+$)/ =~ h["series"]
        title = [h["title-main"], h["title-sub"]].compact.join " - "
        release_date = RelatonBib.parse_date h["published-date"], false
        Hit.new({ code: docidentifier(h), series: series.upcase, title: title, url: h["uri"],
                  status: h["status"], release_date: release_date, json: h }, self)
      end
    end

    def docidentifier(json) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
      parts = doi_parts(json) || code_parts(json["docidentifier"])
      # return json["docidentifier"] unless parts

      id = parts[:code]
      id = "NIST #{parts[:series]} #{id}" if parts[:series]
      id += " Part #{parts[:prt]}" if parts[:prt]
      id += " Vol. #{parts[:vol]}" if parts[:vol]
      id += " Ver. #{parts[:ver]}" if parts[:ver]
      id += " Rev. #{parts[:rev]}" if parts[:rev]
      id += "-Add" if parts[:add]
      id += " (Draft)" if parts[:draft] || @opts[:stage]
      id
    end

    #
    # Select data from json
    #
    # @return [Array<Hash>] selected data
    #
    def select_data # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength,Metrics/PerceivedComplexity
      return [] unless refparts[:code]

      ref = "#{refparts[:series]} #{refparts[:code]}"
      d = Date.strptime year, "%Y" if year
      statuses = %w[draft-public draft-prelim]
      PubsExport.instance.data.select do |doc|
        next unless match_year?(doc, d)

        if @opts[:stage]&.include?("PD")
          next unless statuses.include? doc["status"]
        else
          next unless doc["status"] == "final"
        end
        doc["docidentifier"].include?(ref) || doc["docidentifier"].include?(full_ref)
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
