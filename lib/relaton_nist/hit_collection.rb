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
      @reference = text # year && !text.match?(/:\d{4}$/) ? "#{text}-#{year}" : text
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
    def search_filter
      refid = ::Pubid::Nist::Identifier.parse(@reference)
      parts = exclude_parts refid
      arr = @array.select do |item|
        pubid = ::Pubid::Nist::Identifier.parse(item.hit[:code].sub(/\.$/, ""))
        pubid.exclude(*parts) == refid
      rescue StandardError
        item.hit[:code] == text
      end
    rescue StandardError
      arr = @array.select { |item| item.hit[:code] == text }
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

    def pubid(id = text)
      Pubid::Nist::Identifier.parse(id).to_s
    rescue StandardError
      id
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
      ref = pubid
      # return [] if ref.empty?

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

      ref = "#{refparts[:series]} #{refparts[:code]}"
      d = Date.strptime year, "%Y" if year
      # statuses = %w[draft-public draft-prelim]
      PubsExport.instance.data.select do |doc|
        next unless match_year?(doc, d)

        # if @opts[:stage]&.include?("PD")
        #   next unless statuses.include? doc["status"]
        # else
        #   next unless doc["iteration"] == "final"
        # end
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
