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

  # let(:nist_data) do
  #   File.read "spec/examples/nist_data.xml", encoding: "UTF-8"
  # end

  context "instance methods" do
    subject { RelatonNist::DataFetcher.new "data", "yaml" }

    it "#index" do
      expect(subject.index).to be_instance_of Relaton::Index::Type
    end

    # let(:out) { "data" }
    # let(:format) { "yaml" }

    before(:each) do
      # expect(OpenURI).to receive(:open_uri).with(RelatonNist::DataFetcher::URL).and_return nist_data
      # expect(Dir).to receive(:exist?).with(out).and_return false
      # expect(FileUtils).to receive(:mkdir_p).with(out)
      # files = ["#{out}/NIST_SP_800-133R1.#{format}", "#{out}/NIST_SP_1190GB-16.#{format}"]
      # expect(Dir).to receive(:[]).with("#{out}/*.#{format}").and_return files
      # expect(FileUtils).to receive(:rm).with(files)
      # expect(File).to receive(:exist?).with(files[0]).and_return false
      # expect(File).to receive(:exist?).with(files[1]).and_return true
      # expect(File).to receive(:write).with(files[0], kind_of(String), encoding: "UTF-8")
      # expect(File).to receive(:write).with(files[1], kind_of(String), encoding: "UTF-8")
    end

    # subject do
    #   fetcher = RelatonNist::DataFetcher.new out, format
    #   fetcher.instance_variable_get(:@files) << "#{out}/NIST_SP_1190GB-16.#{format}"
    #   fetcher
    # end

    context "#fetch" do
      before { expect(FileUtils).to receive(:mkdir_p).with("data") }

      it "success" do
        expect(subject.index).to receive(:save)
        expect(subject).to receive(:fetch_tech_pubs)
        subject.fetch
      end

      it "raise error" do
        expect(subject).to receive(:fetch_tech_pubs).and_raise StandardError.new("Test error")
        expect { subject.fetch }.to output(/Test error/).to_stderr
      end
    end

    it "#fetch_tech_pubs" do
      xml = <<~XML
        <body>
          <query>
            <doi_record>
              <report-paper>
                <report-paper_metadata language="en">
                  <titles></titles>
                </report-paper_metadata>
              </report-paper>
            </doi_record>
          </query>
        </body>
      XML
      expect(OpenURI).to receive(:open_uri).with(RelatonNist::DataFetcher::URL).and_return xml
      expect(RelatonNist::TechPubsParser).to receive(:parse)
        .with(kind_of(Nokogiri::XML::Element), kind_of(Hash)).and_return :bib
      expect(subject).to receive(:write_file).with(:bib)
      subject.fetch_tech_pubs
    end

    context "#write_file" do
      let(:bib) { double "BibItem", docidentifier: [double(id: "NIST IR 8296-12")] }

      before do
        expect(subject.index).to receive(:add_or_update).with("NIST IR 8296-12", "data/NISTIR_8296-12.yaml")
        expect(File).to receive(:write).with("data/NISTIR_8296-12.yaml", :content, encoding: "UTF-8")
        expect(subject).to receive(:output).with(bib).and_return :content
      end

      it "success" do
        expect { subject.write_file bib }.not_to output.to_stderr
      end

      it "file exists" do
        subject.instance_variable_set :@files, ["data/NISTIR_8296-12.yaml"]
        expect { subject.write_file bib }.to output(
          /File data\/NISTIR_8296-12\.yaml exists\. Docid: NIST IR 8296-12/,
        ).to_stderr
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

    # context "custom dir & type XML" do
    #   let(:out) { "dir" }
    #   let(:format) { "xml" }

    #   it "fetch" do
    #     expect(subject.index).to receive(:save)
    #     expect { subject.fetch }.to output(
    #       /File dir\/NIST_SP_1190GB-16\.xml exists\. Docid: NIST SP 1190GB-16/,
    #     ).to_stderr
    #   end

    #   it "fetch" do
    #     subject.instance_variable_set :@format, "bibxml"
    #     expect(subject.index).to receive(:save)
    #     expect { subject.fetch }.to output(
    #       /File dir\/NIST_SP_1190GB-16\.xml exists\. Docid: NIST SP 1190GB-16/,
    #     ).to_stderr
    #   end
    # end
  end

  # it "raise parsing error" do
  #   expect(FileUtils).to receive(:mkdir_p).with("data")
  #   expect(subject).to receive(:fetch_tech_pubs).and_raise StandardError.new("Test error")
  #   expect { subject.fetch }.to output(/Test error/).to_stderr
  # end

  # context "parse document" do
  #   subject { RelatonNist::DataFetcher.new "dir", "xml" }
  #   let(:rep) do
  #     doc = Nokogiri::XML File.read("spec/examples/report-paper.xml", encoding: "UTF-8")
  #     doc.at "/report-paper_metadata"
  #   end
  # end
end
