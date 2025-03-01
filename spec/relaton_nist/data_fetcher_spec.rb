RSpec.describe RelatonNist::DataFetcher do
  it "initialize" do
    df = described_class.new "data", "bibxml"
    expect(df.instance_variable_get(:@output)).to eq "data"
    expect(df.instance_variable_get(:@format)).to eq "bibxml"
    expect(df.instance_variable_get(:@ext)).to eq "xml"
    expect(df.instance_variable_get(:@files)).to eq []
  end

  context "create instanse and call fetch" do
    let(:df) { double "fetcher" }
    before { expect(df).to receive(:fetch) }

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
    subject { RelatonNist::DataFetcher.new "data", "yaml" }
    let(:xml) { File.read "spec/examples/allrecords-MODS.xml", encoding: "UTF-8" }

    it "#index" do
      expect(subject.index).to be_instance_of Relaton::Index::Type
    end

    context "#fetch" do
      before { expect(FileUtils).to receive(:mkdir_p).with("data") }

      it "success" do
        expect(subject.index).to receive(:save)
        expect(subject).to receive(:fetch_tech_pubs)
        expect(subject).to receive(:add_static_files)
        subject.fetch
      end

      # it "raise error" do
      #   expect(subject).to receive(:fetch_tech_pubs).and_raise StandardError.new("Test error")
      #   expect { subject.fetch }.to output(/Test error/).to_stderr_from_any_process
      # end
    end

    it "#fetch_tech_pubs" do
      io = double "io", read: xml
      expect(OpenURI).to receive(:open_uri).with(RelatonNist::DataFetcher::URL).and_return io
      parser = double "parser"
      expect(parser).to receive(:parse).and_return(:bib).twice
      expect(RelatonNist::ModsParser).to receive(:new)
        .with(kind_of(LocMods::Record), kind_of(Hash)).and_return(parser).twice
      expect(subject).to receive(:write_file).with(:bib).twice
      subject.fetch_tech_pubs
    end

    it "#add_static_files" do
      expect(Dir).to receive(:[]).with("./static/*.yaml").and_return ["./static/NISTIR_8296-12.yaml"]
      expect(YAML).to receive(:load_file).with("./static/NISTIR_8296-12.yaml").and_return :hash
      docid = RelatonBib::DocumentIdentifier.new type: "NIST", id: "NIST IR 8296-12"
      bib = RelatonNist::NistBibliographicItem.new docid: [docid]
      expect(RelatonNist::NistBibliographicItem).to receive(:from_hash).with(:hash).and_return bib
      expect(subject.index).to receive(:add_or_update).with("NIST IR 8296-12", "./static/NISTIR_8296-12.yaml")
      subject.add_static_files
    end

    context "#write_file" do
      let(:bib) { double "BibItem", docidentifier: [double(id: "NIST IR 8296-12")] }

      before do
        expect(subject.index).to receive(:add_or_update).with("NIST IR 8296-12", "data/NISTIR_8296-12.yaml")
        expect(File).to receive(:write).with("data/NISTIR_8296-12.yaml", :content, encoding: "UTF-8")
        expect(subject).to receive(:output).with(bib).and_return :content
      end

      it "success" do
        expect { subject.write_file bib }.not_to output.to_stderr_from_any_process
      end

      it "file exists" do
        subject.instance_variable_set :@files, ["data/NISTIR_8296-12.yaml"]
        expect { subject.write_file bib }.to output(
          /File data\/NISTIR_8296-12\.yaml exists\. Docid: NIST IR 8296-12/,
        ).to_stderr_from_any_process
      end
    end

    context "#output" do
      let(:bib) { double "BibItem" }

      it "yaml" do
        expect(bib).to receive(:to_hash).and_return id: "NIST IR 8296-12"
        expect(subject.output(bib)).to eq "---\n:id: NIST IR 8296-12\n"
      end

      it "xml" do
        subject.instance_variable_set :@format, "xml"
        expect(bib).to receive(:to_xml).with(bibdata: true).and_return :xml
        expect(subject.output(bib)).to eq :xml
      end

      it "bibxml" do
        subject.instance_variable_set :@format, "bibxml"
        expect(bib).to receive(:to_bibxml).with(no_args).and_return :bibxml
        expect(subject.output(bib)).to eq :bibxml
      end
    end
  end
end
