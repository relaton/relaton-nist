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
        HitCollection.search text, year, opts
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
      def get(code, year = nil, opts = {})
        return fetch_ref_err(code, year, []) if code.match? /\sEP$/

        /^(?<code2>[^\(]+)(\((?<date2>\w+\s(\d{2},\s)?\d{4})\))?\s?\(?((?<=\()(?<stage>[^\)]+))?/ =~ code
        stage ||= /(?<=\.)PD-\w+(?=\.)/.match(code)&.to_s
        if code2
          code = code2.strip
          if date2
            if /\w+\s\d{4}/.match? date2
              opts[:issued_date] = Date.strptime date2, "%B %Y"
            elsif /\w+\s\d{2},\s\d{4}/.match? date2
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
        nistbib_get1(code, year, opts)
      end

      private

      def nistbib_get1(code, year, opts)
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
      def nistbib_results_filter(result, year, opts)
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
      def nistbib_search_filter(code, year, opts) # rubocop:disable Metrics/MethodLength
        warn "[relaton-nist] (\"#{code}\") fetching..."
        # match = %r{
        #   ^((?:NIST)\s)?
        #   (?<serie>(SP|FIPS|NISTIR|ITL\sBulletin|White\sPaper))\s
        #   (?<code>[0-9-]{3,}[A-Z]?)
        #   (?<prt1>pt\d+)?
        #   (?<vol1>v\d+)?
        #   (?<ver1>ver[\d\.]+)?
        #   (?<rev1>r\d+)?
        #   (\s(?<prt2>Part\s\d+))?
        #   (\s(?<vol2>Vol\.\s\d+))?
        #   (\s(?<ver2>(Ver\.|Version)\s[\d\.]+))?
        #   (\s(?<rev2>Rev\.\s\d+))?
        #   (\/(?<upd>Add))?
        # }x.match(code)
        # match ||= %r{
        #   ^NIST\.
        #   (?<serie>(SP|FIPS|IR|ITL\sBulletin|White\sPaper))\.
        #   ((PD-\d+|PUB)\.)?
        #   (?<code>[0-9-]{3,}[A-Z]?)
        #   (\.(?<prt1>pt-\d+))?
        #   (\.(?<vol1>v-\d+))?
        #   (\.(?<ver1>ver-[\d\.]+))?
        #   (\.(?<rev1>r-\d+))?
        # }x.match(code)
        matches = {
          serie: match(/(SP|FIPS|(NIST)?IR|ITL\sBulletin|White\sPaper)(?=\.|\s)/, code),
          code: match(/(?<=\.|\s)[0-9-]{3,}[A-Z]?/, code),
          prt1: match(/(?<=(\.))?pt(?(1)-)[A-Z\d]+/, code),
          vol1: match(/(?<=(\.))?v(?(1)-)\d+/, code),
          ver1: match(/(?<=(\.))?ver(?(1)[-\d]|[\.\d])+/, code)&.gsub(/-/, "."),
          rev1: match(/(?<=[^a-z])(?<=(\.))?r(?(1)-)\d+/, code),
          add1: match(/(?<=(\.))?add(?(1)-)\d+/, code),
          prt2: match(/(?<=\s)Part\s[A-Z\d]+/, code),
          vol2: match(/(?<=\s)Vol\.\s\d+/, code),
          ver2: match(/(?<=\s)Ver\.\s\d+/, code),
          rev2: match(/(?<=\s)Rev\.\s\d+/, code),
          add2: match(/(?<=\/)Add/, code),
        }
        ref = matches[:code] ? "#{matches[:serie]} #{matches[:code]}" : code
        result = search(ref, year, opts)
        selected_result = result.select { |i| search_filter i, matches, code }
        return selected_result if selected_result.any? || !matches[:code]

        search full_ref(matches)
      end

      def full_ref(matches)
        ref = "#{matches[:serie]} #{matches[:code]}"
        ref += long_to_short(matches[:prt1], matches[:prt2]).to_s
        ref += long_to_short(matches[:vol1], matches[:vol2]).to_s
        ref
      end

      def match(regex, code)
        regex.match(code)&.to_s
      end

      # @param item [RelatonNist::Hit]
      # @param matches [Hash]
      # @param text [String]
      # @return [Boolean]
      def search_filter(item, matches, text) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        %r{
          ^((?:NIST)\s)?
          ((?<serie>(SP|FIPS|NISTIR|ITL\sBulletin|White\sPaper))\s)?
          (?<code>[0-9-]{3,}[A-Z]?)
          (?<prt1>pt\d+)?
          (?<vol1>v\d+)?
          (?<ver1>ver[\d.]+)?
          (?<rev1>r\d+)?
          (\s(?<prt2>Part\s\d+))?
          (\s(?<vol2>Vol\.\s\d+))?
          (\s(?<ver2>(Ver\.|Version)\s[\d.]+))?
          (\s(?<rev2>Rev\.\s\d+))?
          (\s(?<add>Add)endum)?
        }x =~ item.hit[:code]
        matches[:code] && [serie, item.hit[:serie]].include?(matches[:serie]) && matches[:code] == code &&
          long_to_short(matches[:prt1], matches[:prt2]) == long_to_short(prt1, prt2) &&
          long_to_short(matches[:vol1], matches[:vol2]) == long_to_short(vol1, vol2) &&
          long_to_short(matches[:ver1], matches[:ver2]) == long_to_short(ver1, ver2) &&
          long_to_short(matches[:rev1], matches[:rev2]) == long_to_short(rev1, rev2) &&
          long_to_short(matches[:add1], matches[:add2]) == add || item.hit[:title].include?(text.sub(/^NIST\s/, ""))
      end

      # @param short [String]
      # @param long [String]
      # @return [String, nil]
      def long_to_short(short, long)
        return short.sub(/-/, "") if short
        return unless long

        long.sub(/Part\s/, "pt").sub(/Vol\.\s/, "v").sub(/Rev\.\s/, "r").sub(/(Ver\.|Version)\s/, "ver")
      end

      def fetch_ref_err(code, year, missed_years)
        id = year ? "#{code}:#{year}" : code
        warn "[relaton-nist] WARNING: no match found online for #{id}. "\
          "The code must be exactly like it is on the standards website."
        warn "[relaton-nist] (There was no match for #{year}, though there were matches "\
          "found for #{missed_years.join(', ')}.)" unless missed_years.empty?
        if /\d-\d/ =~ code
          warn "[relaton-nist] The provided document part may not exist, "\
            "or the document may no longer be published in parts."
        end
        nil
      end
    end
  end
end
