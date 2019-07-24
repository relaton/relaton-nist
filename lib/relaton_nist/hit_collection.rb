# frozen_string_literal: true

require "zip"
require "fileutils"
require "relaton_nist/hit"
require "addressable/uri"
require "open-uri"

module RelatonNist
  # Page of hit collection.
  class HitCollection < Array
    DOMAIN = "https://csrc.nist.gov"
    DATAFILE = File.expand_path "data/pubs-export.zip", __dir__

    # @return [TrueClass, FalseClass]
    attr_reader :fetched

    # @return [String]
    attr_reader :text

    # @return [String]
    attr_reader :year

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

    # @param ref_nbr [String]
    # @param year [String]
    # @param opts [Hash]
    # @option opts [String] :stage
    def initialize(ref_nbr, year = nil, opts = {})
      @text = ref_nbr
      @year = year

      /(?<docid>(SP|FIPS)\s[0-9-]+)/ =~ text
      hits = docid ? from_json(docid, **opts) : from_csrc(**opts)

      hits.sort! do |a, b|
        if a.sort_value != b.sort_value
          b.sort_value - a.sort_value
        else
          (b.hit[:release_date] - a.hit[:release_date]).to_i
        end
      end
      concat hits
      @fetched = false
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # @return [Iecbib::HitCollection]
    def fetch
      workers = RelatonBib::WorkersPool.new 4
      workers.worker(&:fetch)
      each do |hit|
        workers << hit
      end
      workers.end
      workers.result
      @fetched = true
      self
    end

    def to_s
      inspect
    end

    # @return [String]
    def inspect
      "<#{self.class}:#{format('%#.14x', object_id << 1)} @fetched=#{@fetched}>"
    end

    private

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

    # @param stage [String]
    # @return [Array<RelatonNist::Hit>]
    def from_csrc(**opts)
      from, to = nil
      if year
        d    = Date.strptime year, "%Y"
        from = d.strftime "%m/%d/%Y"
        to   = d.next_year.prev_day.strftime "%m/%d/%Y"
      end
      url  = "#{DOMAIN}/publications/search?keywords-lg=#{text}"
      url += "&dateFrom-lg=#{from}" if from
      url += "&dateTo-lg=#{to}" if to
      url += if /PD/ =~ opts[:stage]
               "&status-lg=Draft,Retired Draft,Withdrawn"
             else
               "&status-lg=Final,Withdrawn"
             end

      doc  = Nokogiri::HTML OpenURI.open_uri(::Addressable::URI.parse(url).normalize)
      doc.css("table.publications-table > tbody > tr").map do |h|
        link  = h.at("td/div/strong/a")
        serie = h.at("td[1]").text.strip
        code  = h.at("td[2]").text.strip
        title = link.text
        url   = DOMAIN + link[:href]
        status = h.at("td[4]").text.strip.downcase
        release_date = Date.strptime h.at("td[5]").text.strip, "%m/%d/%Y"
        Hit.new(
          {
            code: code, serie: serie, title: title, url: url, status: status,
            release_date: release_date
          }, self
        )
      end
    end

    # Fetches data form json
    # @param docid [String]
    def from_json(docid, **opts)
      data.select do |doc|
        if year
          d = Date.strptime year, "%Y"
          idate = RelatonNist.parse_date doc["issued-date"]
          next unless idate.between? d, d.next_year.prev_day
        end
        if /PD/ =~ opts[:stage]
          next unless %w[draft-public draft-prelim].include? doc["status"]
        else
          next unless doc["status"] == "final"
        end
        doc["docidentifier"] =~ Regexp.new(docid)
      end.map do |h|
        /(?<serie>(?<=-)\w+$)/ =~ h["series"]
        title = [h["title-main"], h["title-sub"]].compact.join " - "
        release_date = RelatonNist.parse_date h["published-date"]
        Hit.new(
          {
            code: h["docidentifier"], serie: serie.upcase, title: title,
            url: h["uri"], status: h["status"], release_date: release_date,
            json: h
          }, self
        )
      end
    end

    # Fetches json data
    # @return [Hash]
    def data
      ctime = File.ctime DATAFILE if File.exist? DATAFILE
      if !ctime || ctime.to_date < Date.today
        resp = OpenURI.open_uri("https://csrc.nist.gov/CSRC/media/feeds/metanorma/pubs-export.meta")
        if !ctime || ctime < resp.last_modified
          @data = nil
          zip = OpenURI.open_uri "https://csrc.nist.gov/CSRC/media/feeds/metanorma/pubs-export.zip"
          zip.close
          FileUtils.mv zip.path, DATAFILE
        end
      end
      return if @data

      Zip::File.open(DATAFILE) do |zf|
        zf.each do |f|
          @data = JSON.parse f.get_input_stream.read
          break
        end
      end
      @data
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end
end
