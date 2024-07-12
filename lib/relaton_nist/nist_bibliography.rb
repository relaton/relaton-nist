require "relaton_nist/nist_bibliographic_item"
require "relaton_nist/document_relation"
require "relaton_nist/scrapper"
require "relaton_nist/hit_collection"
require "relaton_nist/xml_parser"
require "relaton_nist/comment_period"
require "relaton_nist/document_status"
require "relaton_nist/hash_converter"

module RelatonNist
  class NistBibliography
    class << self
      #
      # Search NIST documents by reference
      #
      # @param text [String] reference
      #
      # @return [RelatonNist::HitCollection] search result
      #
      def search(text, year = nil, opts = {})
        ref = text.sub(/^NISTIR/, "NIST IR")
        HitCollection.search ref, year, opts
      rescue OpenURI::HTTPError, SocketError, OpenSSL::SSL::SSLError => e
        raise RelatonBib::RequestError, e.message
      end

      #
      # Get NIST document by reference
      #
      # @param code [String] the NIST standard Code to look up (e..g "8200")
      # @param year [String] the year the standard was published (optional)
      #
      # @param opts [Hash] options
      # @option opts [Boolean] :all_parts restricted to all parts
      #   if all-parts reference is required
      #
      # @return [RelatonNist::NistBibliographicItem, nil] bibliographic item
      #
      def get(code, year = nil, opts = {}) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        return fetch_ref_err(code, year, []) if code.match?(/\sEP$/)

        /^(?<code2>[^(]+)(?:\((?<date2>\w+\s(?:\d{2},\s)?\d{4})\))?\s?\(?(?:(?<=\()(?<stage>(?:I|F|\d)PD))?/ =~ code
        stage ||= /(?<=\.)PD-\w+(?=\.)/.match(code)&.to_s
        if code2
          code = code2.strip
          if date2
            case date2
            when /\w+\s\d{4}/
              opts[:date] = Date.strptime date2, "%B %Y"
            when /\w+\s\d{2},\s\d{4}/
              opts[:date] = Date.strptime date2, "%B %d, %Y"
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
        nistbib_get(code, year, opts)
      end

      private

      #
      # Get NIST document by reference
      #
      # @param [String] code reference
      # @param [String] year year
      # @param [Hash] opts options
      # @option opts [Date] :issued_date issued date
      # @option opts [Date] :updated_date updated date
      # @option opts [String] :stage stage
      #
      # @return [RelatonNist::NistBibliographicItem, nil] bibliographic item
      #
      def nistbib_get(code, year, opts)
        result = nistbib_search_filter(code, year, opts) || (return nil)
        ret = nistbib_results_filter(result, year, opts)
        if ret[:ret]
          Util.info "Found: `#{ret[:ret].docidentifier.first.id}`", key: result.reference
          ret[:ret]
        else
          fetch_ref_err(result.reference, year, ret[:years])
        end
      end

      #
      # Sort through the results from RelatonNist, fetching them three at a time,
      # and return the first result that matches the code,
      # matches the year (if provided), and which # has a title (amendments do not).
      # Only expects the first page of results to be populated.
      # Does not match corrigenda etc (e.g. ISO 3166-1:2006/Cor 1:2007)
      # If no match, returns any years which caused mismatch, for error reporting
      #
      # @param opts [Hash] options
      # @option opts [Date] :issued_date issued date
      # @option opts [Date] :issued_date issued date
      # @option opts [String] :stage stage
      #
      # @return [Hash] result
      #
      def nistbib_results_filter(result, year, opts) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        missed_years = []
        iter = /\w+(?=PD)|(?<=PD-)\w+/.match(opts[:stage])&.to_s
        iteration = case iter
                    when "I" then "1"
                    when "F" then "final"
                    else iter
                    end
        result.each do |h|
          r = h.fetch
          if opts[:date]
            dates = r.date.select { |d| d.on(:date) == opts[:date] }
            next if dates.empty?
          end
          next if iter && r.status.iteration != iteration
          return { ret: r } if !year

          r.date.select { |d| d.type == "published" || d.type == "issued" }.each do |d|
            return { ret: r } if year.to_i == d.on(:year)

            missed_years << d.on(:year)
          end
        end
        { years: missed_years }
      end

      #
      # Fetch pages for all the hits in parallel
      #
      # @param hits [RelatonNist::HitCollection] hits
      # @param threads [Integer] number of threads
      #
      # @return [Array<RelatonNist::NistBibliographicItem>] bibliographic items
      #
      # def fetch_pages(hits, threads)
      #   workers = RelatonBib::WorkersPool.new threads
      #   workers.worker { |w| { i: w[:i], hit: w[:hit].fetch } }
      #   hits.each_with_index { |hit, i| workers << { i: i, hit: hit } }
      #   workers.end
      #   workers.result.sort_by { |a| a[:i] }.map { |x| x[:hit] }
      # end

      #
      # Get search results and filter them by code and year
      #
      # @param code [String] reference
      # @param year [String, nil] year
      # @param opts [Hash] options
      # @option opts [String] :stage stage
      #
      # @return [RelatonNist::HitCollection] hits collection
      #
      def nistbib_search_filter(code, year, opts)
        result = search(code, year, opts)
        result.search_filter
      end

      #
      # Outputs warning message if no match found
      #
      # @param [String] ref reference
      # @param [String, nil] year year
      # @param [Array<String>] missed_years missed years
      #
      # @return [nil] nil
      #
      def fetch_ref_err(ref, year, missed_years)
        Util.info "No found.", key: ref
        unless missed_years.empty?
          Util.info "(There was no match for #{year}, though there " \
                    "were matches found for `#{missed_years.join('`, `')}`.)", key: ref
        end
        if /\d-\d/.match? ref
          Util.info "The provided document part may not exist, " \
                    "or the document may no longer be published in parts.", key: ref
        end
        nil
      end
    end
  end
end
