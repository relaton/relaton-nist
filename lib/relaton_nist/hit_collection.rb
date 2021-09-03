# frozen_string_literal: true

require "zip"
require "fileutils"
require "relaton_nist/hit"
require "addressable/uri"
require "open-uri"

module RelatonNist
  # Page of hit collection.
  class HitCollection < RelatonBib::HitCollection
    DOMAIN = "https://csrc.nist.gov"
    PUBS_EXPORT = URI.join(DOMAIN, "/CSRC/media/feeds/metanorma/pubs-export")
    DATAFILEDIR = File.expand_path ".relaton/nist", Dir.home
    DATAFILE = File.expand_path "pubs-export.zip", DATAFILEDIR
    GHNISTDATA = "https://raw.githubusercontent.com/relaton/relaton-data-nist/main/data/"

    def self.search(text, year = nil, opts = {})
      new(text, year).search(opts)
    end

    def search(opts)
      @array = from_json(**opts)
      @array = from_ga unless @array.any?
      sort_hits!
    end

    private

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

    def from_ga # rubocop:disable Metrics/AbcSize
      fn = text.gsub(%r{[/\s:.]}, "_").upcase
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

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

    # @param stage [String]
    # @return [Array<RelatonNist::Hit>]
    # def from_csrc(**opts)
    #   from, to = nil
    #   if year
    #     d    = Date.strptime year, "%Y"
    #     from = d.strftime "%m/%d/%Y"
    #     to   = d.next_year.prev_day.strftime "%m/%d/%Y"
    #   end
    #   url = "#{DOMAIN}/publications/search?keywords-lg=#{text}"\
    #         "&sortBy-lg=relevence"
    #   url += "&dateFrom-lg=#{from}" if from
    #   url += "&dateTo-lg=#{to}" if to
    #   url += if /PD/.match? opts[:stage]
    #            "&status-lg=Draft,Retired Draft,Withdrawn"
    #          else
    #            "&status-lg=Final,Withdrawn"
    #          end

    #   doc = Nokogiri::HTML OpenURI.open_uri(::Addressable::URI.parse(url).normalize)
    #   doc.css("table.publications-table > tbody > tr").map do |h|
    #     link  = h.at("td/div/strong/a")
    #     serie = h.at("td[1]").text.strip
    #     code  = h.at("td[2]").text.strip
    #     title = link.text
    #     doc_url = DOMAIN + link[:href]
    #     status = h.at("td[4]").text.strip.downcase
    #     release_date = Date.strptime h.at("td[5]").text.strip, "%m/%d/%Y"
    #     Hit.new(
    #       {
    #         code: code, serie: serie, title: title, url: doc_url,
    #         status: status, release_date: release_date
    #       }, self
    #     )
    #   end
    # end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # Fetches data form json
    # @param stage [String]
    # @return [Array<RelatonNist::Hit>]
    def from_json(**opts)
      select_data(**opts).map do |h|
        /(?<serie>(?<=-)\w+$)/ =~ h["series"]
        title = [h["title-main"], h["title-sub"]].compact.join " - "
        release_date = RelatonBib.parse_date h["published-date"], false
        Hit.new({ code: h["docidentifier"], serie: serie.upcase, title: title,
                  url: h["uri"], status: h["status"],
                  release_date: release_date, json: h }, self)
      end
    end

    # @param stage [String]
    # @return [Array<Hach>]
    def select_data(**opts) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength,Metrics/PerceivedComplexity
      d = Date.strptime year, "%Y" if year
      statuses = %w[draft-public draft-prelim]
      data.select do |doc|
        next unless match_year?(doc, d)

        if /PD/.match? opts[:stage]
          next unless statuses.include? doc["status"]
        else
          next unless doc["status"] == "final"
        end
        doc["docidentifier"].include? text
      end
    end

    # @param doc [Hash]
    # @param date [Date] first day of year
    # @return [TrueClass, FalseClass]
    def match_year?(doc, date)
      return true unless year

      idate = RelatonBib.parse_date doc["issued-date"], false
      idate.between? date, date.next_year.prev_day
    end

    # Fetches json data form server
    # @return [Hash]
    def data
      ctime = File.ctime DATAFILE if File.exist? DATAFILE
      if !ctime || ctime.to_date < Date.today
        fetch_data(ctime)
      end
      unzip
    end

    # Fetch data form server and save it to file
    #
    # @prarm ctime [Time, NilClass]
    def fetch_data(ctime)
      # resp = OpenURI.open_uri("#{PUBS_EXPORT}.meta")
      if !ctime || ctime < OpenURI.open_uri("#{PUBS_EXPORT}.meta").last_modified
        @data = nil
        uri_open = URI.method(:open) || Kernel.method(:open)
        FileUtils.mkdir_p DATAFILEDIR unless Dir.exist? DATAFILEDIR
        IO.copy_stream(uri_open.call("#{PUBS_EXPORT}.zip"), DATAFILE)
      end
    end

    # upack zip file
    #
    # @return [Hash]
    def unzip
      return @data if @data

      Zip::File.open(DATAFILE) do |zf|
        zf.each do |f|
          @data = JSON.parse f.get_input_stream.read
          break
        end
      end
      @data
    end
  end
end
