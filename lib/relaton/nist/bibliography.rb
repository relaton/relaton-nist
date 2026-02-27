module Relaton
  module Nist
    class Bibliography
      extend Core::DateParser

      class << self
        #
        # Search NIST documents by reference
        #
        # @param text [String] reference
        #
        # @return [Relaton::Nist::HitCollection] search result
        #
        def search(text, year = nil, opts = {})
          ref = text.sub(/^NISTIR/, "NIST IR")
          HitCollection.search ref, year, opts
        rescue OpenURI::HTTPError, SocketError, OpenSSL::SSL::SSLError => e
          raise Relaton::RequestError, e.message
        end

        #
        # Get NIST document by reference
        #
        # @param code [String] the NIST standard Code to look up
        # @param year [String] the year the standard was published (optional)
        # @param opts [Hash] options
        # @option opts [Boolean] :all_parts restricted to all parts
        #
        # @return [Relaton::Nist::ItemData, nil] bibliographic item
        #
        def get(code, year = nil, opts = {}) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
          return fetch_ref_err(code, year, []) if code.match?(/\sEP$/)

          /^(?<code2>[^(]+)(?:\((?<date2>\w+\s(?:\d{2},\s)?\d{4})\))?\s?\(?(?:(?<=\()(?<stage>(?:I|F|\d)PD))?/ =~ code
          stage ||= /(?<=\.)PD-\w+(?=\.)/.match(code)&.to_s
          if code2
            code = code2.strip
            opts[:date] = parse_date(date2, str: false) if date2
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
        #
        # @return [Relaton::Nist::ItemData, nil] bibliographic item
        #
        def nistbib_get(code, year, opts)
          result = nistbib_search_filter(code, year, opts) || (return nil)
          ret = nistbib_results_filter(result, year, opts)
          if ret[:ret]
            Util.info "Found: `#{ret[:ret].docidentifier.first.content}`", key: result.reference
            ret[:ret]
          else
            fetch_ref_err(result.reference, year, ret[:years])
          end
        end

        #
        # Sort through results, return first match by code, year, and title
        #
        # @param opts [Hash] options
        # @option opts [Date] :date date filter
        # @option opts [String] :stage stage filter
        #
        # @return [Hash] result
        #
        def nistbib_results_filter(result, year, opts)
          missed_years = []
          iteration = parse_iteration(opts[:stage])

          result.each do |h|
            r = h.item
            next if opts[:date] && !match_date?(r, opts[:date])
            next if iteration && r.status&.iteration != iteration
            return { ret: r } unless year
            next unless match_year?(r, year) { |y| missed_years << y }

            return { ret: r }
          end
          { years: missed_years }
        end

        def parse_iteration(stage)
          iter = /\w+(?=PD)|(?<=PD-)\w+/.match(stage)&.to_s
          case iter
          when "I" then "1"
          when "F" then "final"
          else iter
          end
        end

        def match_date?(item, date)
          item.date.any? do |d|
            date_val = d.at || d.from
            date_val && parse_date(date_val.to_s, str: false) == date
          end
        end

        def match_year?(item, year)
          item.date.select { |d| d.type == "published" || d.type == "issued" }.each do |d|
            date_val = d.at || d.from
            next unless date_val

            parsed_year = parse_date(date_val.to_s, str: false)&.year
            return parsed_year if year.to_i == parsed_year

            yield parsed_year if block_given?
          end
          nil
        end

        #
        # Get search results and filter them by code and year
        #
        # @param code [String] reference
        # @param year [String, nil] year
        # @param opts [Hash] options
        #
        # @return [Relaton::Nist::HitCollection] hits collection
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
          Util.info "Not found.", key: ref
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
end
