# frozen_string_literal: true

require "yaml"
require "loc_mods"
require_relative "mods_parser"

module RelatonNist
  class DataFetcher
    URL = "https://github.com/usnistgov/NIST-Tech-Pubs/releases/download/Nov2024/allrecords-MODS.xml"

    def initialize(output, format)
      @output = output
      @format = format
      @ext = format.sub(/^bib/, "")
      @files = []
    end

    def index
      @index ||= Relaton::Index.find_or_create :nist, file: "index-v1.yaml"
    end

    def series
      @series ||= YAML.load_file File.expand_path("series.yaml", __dir__)
    end

    #
    # Save document
    #
    # @param bib [RelatonNist::NistBibliographicItem]
    #
    def write_file(bib) # rubocop:disable Metrics/AbcSize
      id = bib.docidentifier[0].id.gsub(%r{[/\s:.]}, "_").upcase.sub(/^NIST_IR/, "NISTIR")
      file = File.join(@output, "#{id}.#{@ext}")
      if @files.include? file
        Util.warn "File #{file} exists. Docid: #{bib.docidentifier[0].id}"
        # warn "Link: #{bib.link.detect { |l| l.type == 'src' }.content}"
      else @files << file
      end
      index.add_or_update bib.docidentifier[0].id, file
      File.write file, output(bib), encoding: "UTF-8"
    end

    def output(bib)
      case @format
      when "yaml" then bib.to_hash.to_yaml
      when "xml" then bib.to_xml bibdata: true
      else bib.send "to_#{@format}"
      end
    end

    #
    # Fetch all the documnts from dataset
    #
    def fetch # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      t1 = Time.now
      puts "Started at: #{t1}"

      FileUtils.mkdir_p @output
      FileUtils.rm Dir[File.join(@output, "*.#{@ext}")]

      fetch_tech_pubs
      add_static_files
      index.save

      t2 = Time.now
      puts "Stopped at: #{t2}"
      puts "Done in: #{(t2 - t1).round} sec."
    # rescue StandardError => e
    #   Util.error "#{e.message}\n#{e.backtrace[0..5].join("\n")}"
    end

    def fetch_tech_pubs
      docs = LocMods::Collection.from_xml OpenURI.open_uri(URL)
      # docs.xpath(
      #   "/body/query/doi_record/report-paper/report-paper_metadata",
      # )
      docs.mods.each { |doc| write_file ModsParser.new(doc, series).parse }
    end

    def add_static_files
      Dir["./static/*.yaml"].each do |file|
        hash = YAML.load_file file
        bib = RelatonNist::NistBibliographicItem.from_hash(hash)
        index.add_or_update bib.docidentifier[0].id, file
      end
    end

    #
    # Fetch all the documnts from dataset
    #
    # @param [String] output foldet name to save the documents
    # @param [String] format format to save the documents (yaml, xml, bibxml)
    #
    def self.fetch(output: "data", format: "yaml")
      new(output, format).fetch
    end
  end
end
