# frozen_string_literal: true

require "zip"
require "fileutils"
require "relaton_nist/hit"
require "addressable/uri"
require "open-uri"

module RelatonNist
  # Hit collection.
  class HitCollection < RelatonBib::HitCollection
    DOMAIN = "https://csrc.nist.gov"
    PUBS_EXPORT = URI.join(DOMAIN, "/CSRC/media/feeds/metanorma/pubs-export")
    DATAFILEDIR = File.expand_path ".relaton/nist", Dir.home
    DATAFILE = File.expand_path "pubs-export.zip", DATAFILEDIR
    GHNISTDATA = "https://raw.githubusercontent.com/relaton/relaton-data-nist/main/data/"

    #
    # Create hits collection instance and search hits
    #
    # @param [Hash] opts options
    # @option opts [String] :stage stage of document
    #
    # @return [RelatonNist::HitCollection] hits collection
    #
    def self.search(text, year = nil, opts = {})
      new(text, year).search(opts)
    end

    #
    # Search nits in JSON file or GitHub repo
    #
    # @param [Hash] opts options
    # @option opts [String] :stage stage of document
    #
    # @return [RelatonNist::HitCollection] hits collection
    #
    def search(opts)
      @array = from_json(**opts)
      @array = from_ga unless @array.any?
      sort_hits!
    end

    #
    # Filter hits by reference's parts
    #
    # @return [Array<RelatonNist::Hit>] hits
    #
    def search_filter # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
      @array.select do |item|
        %r{
          ^(?:(?:NIST|NBS)\s?)?
          (?:(?<series>(?:SP|FIPS|IR|ITL\sBulletin|White\sPaper))\s)?
          (?<code>[0-9-]{3,}[A-Z]?)
          (?<prt1>pt\d+)?
          (?<vol1>v\d+)?
          (?<ver1>ver[\d.]+)?
          (?<rev1>r\d+)?
          (?:\s(?<prt2>Part\s\d+))?
          (?:\s(?<vol2>Vol\.\s\d+))?
          (?:\s(?<ver2>(?:Ver\.|Version)\s[\d.]+))?
          (?:\s(?<rev2>Rev\.\s\d+))?
          (?:\s(?<add>Add)endum)?
        }x =~ item.hit[:code]
        (refparts[:code] && [series, item.hit[:series]].include?(refparts[:series]) && refparts[:code] == code &&
          long_to_short(refparts[:prt1], refparts[:prt2]) == long_to_short(prt1, prt2) &&
          long_to_short(refparts[:vol1], refparts[:vol2]) == long_to_short(vol1, vol2) &&
          long_to_short(refparts[:ver1], refparts[:ver2]) == long_to_short(ver1, ver2) &&
          long_to_short(refparts[:rev1], refparts[:rev2]) == long_to_short(rev1, rev2) &&
          long_to_short(refparts[:add1], refparts[:add2]) == add) || item.hit[:title]&.include?(text.sub(/^NIST\s/, ""))
      end
    end

    private

    #
    # Parse reference parts
    #
    # @return [Hash] reference parts
    #
    def refparts # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      @refparts ||= {
        perfix: match(/^(NIST|NBS)\s?/, text),
        series: match(/(SP|FIPS|IR|ITL\sBulletin|White\sPaper)(?=\.|\s)/, text),
        code: match(/(?<=\.|\s)[0-9-]{3,}[A-Z]?/, text),
        prt1: match(/(?<=(\.))?pt(?(1)-)[A-Z\d]+/, text),
        vol1: match(/(?<=(\.))?v(?(1)-)\d+/, text),
        ver1: match(/(?<=(\.))?ver(?(1)[-\d]|[.\d])+/, text)&.gsub(/-/, "."),
        rev1: match(/(?<=[^a-z])(?<=(\.))?r(?(1)-)\d+/, text),
        add1: match(/(?<=(\.))?add(?(1)-)\d+/, text),
        prt2: match(/(?<=\s)Part\s[A-Z\d]+/, text),
        vol2: match(/(?<=\s)Vol\.\s\d+/, text),
        ver2: match(/(?<=\s)Ver\.\s\d+/, text),
        rev2: match(/(?<=\s)Rev\.\s\d+/, text),
        add2: match(/(?<=\/)Add/, text),
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
      regex.match(code)&.to_s
    end

    #
    # Generate reference from parts
    #
    # @return [String] reference
    #
    def full_ref # rubocop:disable Metrics/AbcSize
      @full_ref ||= begin
        ref = "#{refparts[:perfix]}#{refparts[:series]} #{refparts[:code]}"
        ref += long_to_short(refparts[:prt1], refparts[:prt2]).to_s
        ref += long_to_short(refparts[:vol1], refparts[:vol2]).to_s
        ref
      end
    end

    #
    # Return short version of ID part with removed "-" or convert long version to short.
    # Converts "pt-1" to "pt1" and "Part 1" to "pt1", "v-1" to "v1" and "Vol. 1" to "v1",
    #   "ver-1" to "ver1" and "Ver. 1" to "ver1", "r-1" to "r1" and "Rev. 1" to "r1".
    #
    # @param short [String]
    # @param long [String]
    #
    # @return [String, nil]
    #
    def long_to_short(short, long)
      return short.sub(/-/, "") if short
      return unless long

      long.sub(/Part\s/, "pt").sub(/Vol\.\s/, "v").sub(/Rev\.\s/, "r").sub(/(Ver\.|Version)\s/, "ver")
    end

    #
    # Sort hits by sort_value and release date
    #
    # @return [self] sorted hits collection
    #
    def sort_hits!
      @array.sort! do |a, b|
        if a.sort_value == b.sort_value
          (b.hit[:release_date] - a.hit[:release_date]).to_i
        else
          b.sort_value - a.sort_value
        end
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
      ref = full_ref
      fn = ref.gsub(%r{[/\s:.]}, "_").upcase
      yaml = OpenURI.open_uri "#{GHNISTDATA}#{fn}.yaml"
      hash = YAML.safe_load yaml
      bib = RelatonNist::NistBibliographicItem.from_hash hash
      hit = Hit.new({ code: text }, self)
      hit.fetch = bib
      [hit]
    rescue OpenURI::HTTPError => e
      return [] if e.io.status[0] == "404"

      raise e
    end

    #
    # Fetches data form json
    #
    # @param opts [Hash] options
    # @option opts [String] :stage stage of document
    #
    # @return [Array<RelatonNist::Hit>] hits
    #
    def from_json(**opts)
      select_data(**opts).map do |h|
        /(?<series>(?<=-)\w+$)/ =~ h["series"]
        title = [h["title-main"], h["title-sub"]].compact.join " - "
        release_date = RelatonBib.parse_date h["published-date"], false
        Hit.new({ code: h["docidentifier"], series: series.upcase, title: title,
                  url: h["uri"], status: h["status"],
                  release_date: release_date, json: h }, self)
      end
    end

    #
    # Select data from json
    #
    # @param opts [Hash] options
    # @option opts [String] :stage stage of document
    #
    # @return [Array<Hash>] selected data
    #
    def select_data(**opts) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength,Metrics/PerceivedComplexity
      ref = "#{refparts[:series]} #{refparts[:code]}"
      d = Date.strptime year, "%Y" if year
      statuses = %w[draft-public draft-prelim]
      data.select do |doc|
        next unless match_year?(doc, d)

        if /PD/.match? opts[:stage]
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

      idate = RelatonBib.parse_date doc["issued-date"], false
      idate.between? date, date.next_year.prev_day
    end

    #
    # Fetches json data form server
    #
    # @return [Array<Hash>] json data
    #
    def data
      ctime = File.ctime DATAFILE if File.exist? DATAFILE
      if !ctime || ctime.to_date < Date.today || File.size(DATAFILE).zero?
        fetch_data(ctime)
      end
      unzip
    end

    #
    # Fetch data form server and save it to file
    #
    # @prarm ctime [Time, nil] file creation time
    #
    def fetch_data(ctime)
      if !ctime || ctime < OpenURI.open_uri("#{PUBS_EXPORT}.meta").last_modified
        @data = nil
        uri_open = URI.method(:open) || Kernel.method(:open)
        FileUtils.mkdir_p DATAFILEDIR
        IO.copy_stream(uri_open.call("#{PUBS_EXPORT}.zip"), DATAFILE)
      end
    end

    #
    # upack zip file
    #
    # @return [Array<Hash>] json data
    #
    def unzip
      return @data if @data

      Zip::File.open(DATAFILE) do |zf|
        @data = JSON.parse zf.first.get_input_stream.read
      end
      @data
    end
  end
end
