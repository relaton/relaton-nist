module RelatonNist
  class PubsExport
    include Singleton

    DOMAIN = "https://csrc.nist.gov".freeze
    PUBS_EXPORT = URI.join(DOMAIN, "/CSRC/media/feeds/metanorma/pubs-export")
    DATAFILEDIR = File.expand_path ".relaton/nist", Dir.home
    DATAFILE = File.expand_path "pubs-export.zip", DATAFILEDIR

    def initialize
      @mutex = Mutex.new
    end

    #
    # Fetches json data form server
    #
    # @return [Array<Hash>] json data
    #
    def data
      @mutex.synchronize do
        @data ||= begin
          ctime = File.ctime DATAFILE if File.exist? DATAFILE
          if !ctime || ctime.to_date < Date.today || File.size(DATAFILE).zero?
            fetch_data(ctime)
          end
          unzip
        end
      end
    end

    private

    #
    # Fetch data form server and save it to file
    #
    # @prarm ctime [Time, nil] file creation time
    #
    def fetch_data(ctime)
      if !ctime || ctime < OpenURI.open_uri("#{PUBS_EXPORT}.meta").last_modified
        @data = nil
        uri_open = URI.method(:open) || Kernel.method(:open)
        FileUtils.mkdir_p DATAFILEDIR
        IO.copy_stream(uri_open.call("#{PUBS_EXPORT}.zip"), DATAFILE)
      end
    end

    #
    # upack zip file
    #
    # @return [Array<Hash>] json data
    #
    def unzip
      Zip::File.open(DATAFILE) do |zf|
        JSON.parse zf.first.get_input_stream.read
      end
    end
  end
end
