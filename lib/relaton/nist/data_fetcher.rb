# frozen_string_literal: true

require "yaml"
require "mechanize"
require "loc_mods"
require_relative "../nist"
require_relative "mods_parser"

module Relaton
  module Nist
    class DataFetcher < Core::DataFetcher
      URL = "https://github.com/usnistgov/NIST-Tech-Pubs/releases/download/Nov2024/allrecords-MODS.xml"

      def fetch(_source = nil)
        FileUtils.rm Dir[File.join(@output, "*.#{@ext}")]
        fetch_tech_pubs
        # add_static_files
        index.save
        report_errors
      end

      def fetch_tech_pubs
        xml_data = Mechanize.new.get(URL).body
        docs = LocMods::Collection.from_xml xml_data
        docs.mods.each { |doc| write_file ModsParser.new(doc, series, @errors).parse }
      end

      def write_file(bib)
        id = bib.docidentifier.find(&:primary) || bib.docidentifier.first
        file = output_file id.content.sub(/^NIST IR/, "NISTIR")
        if @files.include? file
          Util.warn "File #{file} exists. Docid: #{bib.docidentifier[0].content}"
        else @files << file
        end
        index.add_or_update bib.docidentifier[0].content, file
        File.write file, serialize(bib), encoding: "UTF-8"
      end

      # def add_static_files
      #   Dir["./static/*.yaml"].each do |file|
      #     bib = Item.from_yaml(File.read(file, encoding: "UTF-8"))
      #     index.add_or_update bib.docidentifier[0].content, file
      #   end
      # end

      def to_yaml(bib)
        Item.to_yaml(bib)
      end

      def to_xml(bib)
        Bibdata.to_xml(bib)
      end

      def to_bibxml(bib)
        bib.to_rfcxml
      end

      def log_error(msg)
        Util.error msg
      end

      def index
        @index ||= Relaton::Index.find_or_create :nist, file: "#{INDEXFILE}.yaml"
      end

      def series
        @series ||= YAML.load_file File.expand_path("series.yaml", __dir__)
      end
    end
  end
end
