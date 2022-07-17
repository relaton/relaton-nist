require "relaton_bib"
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
      # @param text [String]
      # @return [RelatonNist::HitCollection]
      def search(text, year = nil, opts = {})
        ref = text.sub(/^NIST\sIR/, "NISTIR")
        HitCollection.search ref, year, opts
      rescue OpenURI::HTTPError, SocketError, OpenSSL::SSL::SSLError => e
        raise RelatonBib::RequestError, e.message
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
      def get(code, year = nil, opts = {}) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        return fetch_ref_err(code, year, []) if code.match?(/\sEP$/)

        /^(?<code2>[^(]+)(?:\((?<date2>\w+\s(?:\d{2},\s)?\d{4})\))?\s?\(?(?:(?<=\()(?<stage>[^\)]+))?/ =~ code
        stage ||= /(?<=\.)PD-\w+(?=\.)/.match(code)&.to_s
        if code2
          code = code2.strip
          if date2
            case date2
            when /\w+\s\d{4}/
              opts[:issued_date] = Date.strptime date2, "%B %Y"
            when /\w+\s\d{2},\s\d{4}/
              opts[:updated_date] = Date.strptime date2, "%B %d, %Y"
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

      def nistbib_get(code, year, opts)
        result = nistbib_search_filter(code, year, opts) || (return nil)
        ret = nistbib_results_filter(result, year, opts)
        if ret[:ret]
          warn "[relaton-nist] (\"#{code}\") found #{ret[:ret].docidentifier.first.id}"
          ret[:ret]
        else
          fetch_ref_err(code, year, ret[:years])
        end
      end

      # Sort through the results from RelatonNist, fetching them three at a time,
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
      # @return [Hash]
      def nistbib_results_filter(result, year, opts) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        missed_years = []
        iter = /\w+(?=PD)|(?<=PD-)\w+/.match(opts[:stage])&.to_s
        iteration = case iter
                    when "I" then "1"
                    when "F" then "final"
                    else iter
                    end
        result.each_slice(3) do |s| # ISO website only allows 3 connections
          fetch_pages(s, 3).each_with_index do |r, _i|
            if opts[:issued_date]
              ids = r.date.select do |d|
                d.type == "issued" && d.on(:date) == opts[:issued_date]
              end
              next if ids.empty?
            elsif opts[:updated_date]
              pds = r.date.select do |d|
                d.type == "published" && d.on(:date) == opts[:updated_date]
              end
              next if pds.empty?
            end
            next if iter && r.status.iteration != iteration
            return { ret: r } if !year

            r.date.select { |d| d.type == "published" }.each do |d|
              return { ret: r } if year.to_i == d.on(:year)

              missed_years << d.on(:year)
            end
          end
        end
        { years: missed_years }
      end

      # @param hits [RelatonNist::HitCollection]
      # @param threads [Integer]
      # @return [Array<RelatonNist::NistBibliographicItem>]
      def fetch_pages(hits, threads)
        workers = RelatonBib::WorkersPool.new threads
        workers.worker { |w| { i: w[:i], hit: w[:hit].fetch } }
        hits.each_with_index { |hit, i| workers << { i: i, hit: hit } }
        workers.end
        workers.result.sort_by { |a| a[:i] }.map { |x| x[:hit] }
      end

      # @param code [String]
      # @param year [String, nil]
      # @param opts [Hash]
      # @return [RelatonNist::HitCollection]
      def nistbib_search_filter(code, year, opts)
        warn "[relaton-nist] (\"#{code}\") fetching..."
        result = search(code, year, opts)
        result.search_filter
      end

      def fetch_ref_err(code, year, missed_years) # rubocop:disable Metrics/MethodLength
        id = year ? "#{code}:#{year}" : code
        warn "[relaton-nist] WARNING: no match found online for #{id}. " \
             "The code must be exactly like it is on the standards website."
        unless missed_years.empty?
          warn "[relaton-nist] (There was no match for #{year}, though there " \
               "were matches found for #{missed_years.join(', ')}.)"
        end
        if /\d-\d/.match? code
          warn "[relaton-nist] The provided document part may not exist, " \
               "or the document may no longer be published in parts."
        end
        nil
      end
    end
  end
end
