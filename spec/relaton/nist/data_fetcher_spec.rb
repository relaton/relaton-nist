# frozen_string_literal: true

require "relaton/nist/data_fetcher"

RSpec.describe Relaton::Nist::DataFetcher do
  context "create instance and call fetch" do
    let(:df) { double "fetcher" }
    before { expect(df).to receive(:fetch).with(nil) }

    it "default output & format" do
      expect(described_class).to receive(:new).with("data", "yaml").and_return df
      described_class.fetch
    end

    it "specified output & format" do
      expect(described_class).to receive(:new).with("dir", "xml").and_return df
      described_class.fetch output: "dir", format: "xml"
    end
  end

  context "instance methods" do
    subject { described_class.new "data", "yaml" }
    let(:xml) { File.read "spec/fixtures/allrecords-MODS.xml", encoding: "UTF-8" }

    it "#index" do
      expect(subject.index).to be_instance_of Relaton::Index::Type
    end

    context "#fetch" do
      it "success" do
        expect(subject.index).to receive(:save)
        expect(subject).to receive(:fetch_tech_pubs)
        # expect(subject).to receive(:add_static_files)
        subject.fetch
      end
    end

    it "#fetch_tech_pubs" do
      page = double("page", body: xml)
      agent = double("agent")
      expect(Mechanize).to receive(:new).and_return agent
      expect(agent).to receive(:get).with(Relaton::Nist::DataFetcher::URL).and_return page
      parser = double "parser"
      expect(parser).to receive(:parse).and_return(:bib).twice
      expect(Relaton::Nist::ModsParser).to receive(:new)
        .with(kind_of(LocMods::Record), kind_of(Hash), kind_of(Hash)).and_return(parser).twice
      expect(subject).to receive(:write_file).with(:bib).twice
      subject.fetch_tech_pubs
    end

    context "#write_file" do
      let(:docid) { Relaton::Bib::Docidentifier.new(type: "NIST", content: "NIST IR 8296-12") }
      let(:bib) { Relaton::Bib::ItemData.new(docidentifier: [docid]) }

      before do
        expect(subject.index).to receive(:add_or_update).with("NIST IR 8296-12", "data/nistir-8296-12.yaml")
        expect(File).to receive(:write).with("data/nistir-8296-12.yaml", :content, encoding: "UTF-8")
        expect(subject).to receive(:serialize).with(bib).and_return :content
      end

      it "success" do
        expect { subject.write_file bib }.not_to output.to_stderr_from_any_process
      end

      it "file exists" do
        subject.instance_variable_get(:@files) << "data/nistir-8296-12.yaml"
        expect { subject.write_file bib }.to output(
          /File data\/nistir-8296-12\.yaml exists\. Docid: NIST IR 8296-12/,
        ).to_stderr_from_any_process
      end
    end

    context "#serialize" do
      let(:bib) { double "BibItem" }

      it "yaml" do
        expect(Relaton::Nist::Item).to receive(:to_yaml).with(bib).and_return :yaml
        expect(subject.serialize(bib)).to eq :yaml
      end

      it "xml" do
        subject.instance_variable_set :@format, "xml"
        expect(Relaton::Nist::Bibdata).to receive(:to_xml).with(bib).and_return :xml
        expect(subject.serialize(bib)).to eq :xml
      end

      it "bibxml" do
        subject.instance_variable_set :@format, "bibxml"
        expect(bib).to receive(:to_rfcxml).with(no_args).and_return :bibxml
        expect(subject.serialize(bib)).to eq :bibxml
      end
    end
  end
end
