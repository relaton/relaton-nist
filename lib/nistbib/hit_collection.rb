# frozen_string_literal: true

require 'nistbib/hit'
require 'nistbib/workers_pool'
require "addressable/uri"
require 'open-uri'

module NistBib
  # Page of hit collection.
  class HitCollection < Array

    DOMAIN = 'https://csrc.nist.gov'

    # @return [TrueClass, FalseClass]
    attr_reader :fetched

    # @return [String]
    attr_reader :text

    # @return [String]
    attr_reader :year

    # @param ref_nbr [String]
    # @param year [String]
    def initialize(ref_nbr, year = nil) #(text, hit_pages = nil)
      @text = ref_nbr
      @year = year
      from, to = nil
      if year
        from = Date.strptime year, '%Y'
        to   = from.next_year.prev_day
      end
      url  = "#{DOMAIN}/publications/search?keywords-lg=#{ref_nbr}&dateFrom-lg=#{from}&dateTo-lg=#{to}&status-lg=Draft,Final"
      doc  = Nokogiri::HTML OpenURI.open_uri(::Addressable::URI.parse(url).normalize)
      hits = doc.css('table.publications-table > tbody > tr').map do |h|
        link  = h.at('td/div/strong/a')
        code  = h.at('td[2]').text.strip
        title = link.text
        url   = DOMAIN + link[:href]
        Hit.new({ code: code, title: title, url: url }, self)
      end
      concat hits
      # concat(hits.map { |h| Hit.new(h, self) })
      @fetched = false
      # @hit_pages = hit_pages
    end

    # @return [Iecbib::HitCollection]
    def fetch
      workers = WorkersPool.new 4
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
