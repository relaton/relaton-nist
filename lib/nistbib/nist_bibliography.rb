require "relaton_bib"
require "nistbib/nist_bibliographic_item"
require "nistbib/scrapper"
require "nistbib/hit_collection"
require "nistbib/xml_parser"
require "nistbib/keyword"
require "nistbib/comment_period"
require "nistbib/document_status"

module NistBib
  class NistBibliography
    class << self
      # @param text [String]
      # @return [NistBib::HitCollection]
      def search(text, year = nil, opts = {})
        HitCollection.new text, year, opts
      rescue OpenURI::HTTPError, SocketError
        warn "Could not access https://www.nist.gov"
        []
      end

      # @param code [String] the NIST standard Code to look up (e..g "8200")
      # @param year [String] the year the standard was published (optional)
      #
      # @param opts [Hash] options
      # @option opts [TrueClass, FalseClass] :all_parts restricted to all parts
      #   if all-parts reference is required
      # @option opts [TrueClass, FalseClass] :bibdata
      #
      # @return [String] Relaton XML serialisation of reference
      def get(code, year = nil, opts = {})
        /^(?<code2>[^\(]+)(\((?<date2>\w+\s(\d{2},\s)?\d{4})\))?\s?\(?((?<=\()(?<stage>[^\)]+))?/ =~ code
        if code2
          code = code2.strip
          if date2
            if /\w+\s\d{4}/ =~ date2
              opts[:issued_date] = Time.strptime date2, "%B %Y"
            elsif /\w+\s\d{2},\s\d{4}/ =~ date2
              opts[:updated_date] = Time.strptime date2, "%B %d, %Y"
            end
          end
          opts[:stage] = stage if stage
        end

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
        result = nistbib_search_filter(code, year, opts) || (return nil)
        ret = nistbib_results_filter(result, year, opts)
        return ret[:ret] if ret[:ret]

        fetch_ref_err(code, year, ret[:years])
      end

      # Sort through the results from NistBib, fetching them three at a time,
      # and return the first result that matches the code,
      # matches the year (if provided), and which # has a title (amendments do not).
      # Only expects the first page of results to be populated.
      # Does not match corrigenda etc (e.g. ISO 3166-1:2006/Cor 1:2007)
      # If no match, returns any years which caused mismatch, for error reporting
      #
      # @param opts [Hash] options
      # @option opts [Time] :issued_date
      # @option opts [Time] :issued_date
      # @option opts [String] :stage
      #
      # @retur [Hash]
      def nistbib_results_filter(result, year, opts)
        missed_years = []
        result.each_slice(3) do |s| # ISO website only allows 3 connections
          fetch_pages(s, 3).each_with_index do |r, _i|
            if opts[:issued_date]
              r.dates.select { |d| d.type == "issued" }.each do |d|
                next unless opts[:issued_date] == d.on
              end
            elsif opts[:updated_date]
              r.dates.select { |d| d.type == "published" }.each do |d|
                next unless opts[:updated_date] == d.on
              end
            end
            if opts[:stage]
              iter = opts[:stage][-3]
              iteration = case iter
                          when "I" then 1
                          when "F" then "final"
                          else iter.to_i
                          end
              next if iter && r.status.iteration != iteration
            end
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
        workers = RelatonBib::WorkersPool.new n
        workers.worker { |w| { i: w[:i], hit: w[:hit].fetch } }
        s.each_with_index { |hit, i| workers << { i: i, hit: hit } }
        workers.end
        workers.result.sort { |x, y| x[:i] <=> y[:i] }.map { |x| x[:hit] }
      end

      def nistbib_search_filter(code, year, opts)
        docid = code.match(%r{[0-9-]{3,}}).to_s
        serie = code.match(%r{(FISP|SP|NISTIR)(?=\s)})
        warn "fetching #{code}..."
        result = search(code, year, opts)
        result.select do |i|
          i.hit[:code]&.include?(docid) && (!serie || i.hit[:serie] == serie.to_s)
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
