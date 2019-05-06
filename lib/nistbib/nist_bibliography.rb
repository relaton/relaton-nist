require "relaton_bib"
require "nistbib/nist_bibliographic_item"
require "nistbib/scrapper"
require "nistbib/hit_collection"
require "nistbib/nist_series"
require "nistbib/xml_parser"
require "nistbib/keyword"
require "nistbib/comment_period"
require "nistbib/document_status"

module NistBib
  class NistBibliography
    class << self
      # @param text [String]
      # @return [NistBib::HitCollection]
      def search(text, year = nil)
        HitCollection.new text, year
      rescue
        warn "Could not access https://www.nist.gov"
        []
      end

      # @param code [String] the NIST standard Code to look up (e..g "8200")
      # @param year [String] the year the standard was published (optional)
      # @param opts [Hash] options; restricted to :all_parts if all-parts reference is required
      # @return [String] Relaton XML serialisation of reference
      def get(code, year = nil, opts = {})
        if year.nil?
          /^(?<code1>[^:]+):(?<year1>[^:]+)$/ =~ code
          unless code1.nil?
            code = code1
            year = year1
          end
        end

        code += "-1" if opts[:all_parts]
        ret = nistbib_get1(code, year, opts)
        # return nil if ret.nil?
        # ret.to_most_recent_reference unless year || opts[:keep_year]
        # ret.to_all_parts if opts[:all_parts]
        ret
      end

      private

      def nistbib_get1(code, year, opts)
        result = nistbib_search_filter(code, year) or return nil
        ret = nistbib_results_filter(result, year)
        return ret[:ret] if ret[:ret]

        fetch_ref_err(code, year, ret[:years])
      end

      # Sort through the results from NistBib, fetching them three at a time,
      # and return the first result that matches the code,
      # matches the year (if provided), and which # has a title (amendments do not).
      # Only expects the first page of results to be populated.
      # Does not match corrigenda etc (e.g. ISO 3166-1:2006/Cor 1:2007)
      # If no match, returns any years which caused mismatch, for error reporting
      def nistbib_results_filter(result, year)
        missed_years = []
        result.each_slice(3) do |s| # ISO website only allows 3 connections
          fetch_pages(s, 3).each_with_index do |r, _i|
            return { ret: r } if !year

            r.dates.select { |d| d.type == "published" }.each do |d|
              return { ret: r } if year.to_i == d.on.year

              missed_years << d.on.year
            end
          end
        end
        { years: missed_years }
      end

      def fetch_pages(s, n)
        workers = WorkersPool.new n
        workers.worker { |w| { i: w[:i], hit: w[:hit].fetch } }
        s.each_with_index { |hit, i| workers << { i: i, hit: hit } }
        workers.end
        workers.result.sort { |x, y| x[:i] <=> y[:i] }.map { |x| x[:hit] }
      end

      def nistbib_search_filter(code, year)
        # docidrx = %r{^(ISO|IEC)[^0-9]*\s[0-9-]+}
        # corrigrx = %r{^(ISO|IEC)[^0-9]*\s[0-9-]+:[0-9]+/}
        warn "fetching #{code}..."
        result = search(code, year)
        result.select do |i|
          !i.hit[:code].empty?
        #   i.hit[:code] &&
        #     i.hit[:code].match(docidrx).to_s == code &&
        #     corrigrx !~ i.hit[:code]
        end
      end

      def fetch_ref_err(code, year, missed_years)
        id = year ? "#{code}:#{year}" : code
        warn "WARNING: no match found online for #{id}. "\
          "The code must be exactly like it is on the standards website."
        warn "(There was no match for #{year}, though there were matches "\
          "found for #{missed_years.join(', ')}.)" unless missed_years.empty?
        if /\d-\d/ =~ code
          warn "The provided document part may not exist, or the document "\
            "may no longer be published in parts."
        end
        nil
      end
    end
  end
end
