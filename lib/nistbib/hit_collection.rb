# frozen_string_literal: true

require "nistbib/hit"
require "addressable/uri"
require "open-uri"

module NistBib
  # Page of hit collection.
  class HitCollection < Array

    DOMAIN = "https://csrc.nist.gov"

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
      from, to = nil
      if year
        d = Date.strptime year, "%Y"
        from = d.strftime "%m/%d/%Y"
        to   = d.next_year.prev_day.strftime "%m/%d/%Y"
      end
      url  = "#{DOMAIN}/publications/search?keywords-lg=#{ref_nbr}"
      url += "&dateFrom-lg=#{from}" if from
      url += "&dateTo-lg=#{to}" if to
      url += if /PD/ =~ opts[:stage]
               "&status-lg=Draft,Retired Draft,Withdrawn"
             else
               "&status-lg=Final,Withdrawn"
             end

      doc  = Nokogiri::HTML OpenURI.open_uri(::Addressable::URI.parse(url).normalize)
      hits = doc.css("table.publications-table > tbody > tr").map do |h|
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
      concat(hits.sort { |a, b| a.sort_value - b.sort_value })
      # concat(hits.map { |h| Hit.new(h, self) })
      @fetched = false
      # @hit_pages = hit_pages
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

    def inspect
      "<#{self.class}:#{format('%#.14x', object_id << 1)} @fetched=#{@fetched}>"
    end
  end
end
