RSpec.describe "NIST documents fetcher" do
  let(:nist_data) do
    File.read "spec/examples/nist_data.xml", encoding: "UTF-8"
  end

  context "fetch data" do
    let(:out) { "data" }
    let(:format) { "yaml" }

    before(:each) do
      expect(OpenURI).to receive(:open_uri).with(RelatonNist::DataFetcher::URL).and_return nist_data
      expect(Dir).to receive(:exist?).with(out).and_return false
      expect(FileUtils).to receive(:mkdir).with(out)
      files = ["#{out}/NIST_SP_800-133R1.#{format}", "#{out}/NIST_SP_1190GB-16.#{format}"]
      expect(Dir).to receive(:[]).with("#{out}/*.#{format}").and_return files
      expect(FileUtils).to receive(:rm).with(files)
      expect(File).to receive(:exist?).with(files[0]).and_return false
      expect(File).to receive(:exist?).with(files[1]).and_return true
      expect(File).to receive(:write).with(files[0], kind_of(String), encoding: "UTF-8")
    end

    it "fetch" do
      expect { RelatonNist::DataFetcher.fetch }.to output(
        /File data\/NIST_SP_1190GB-16\.yaml exists\. Docid: NIST SP 1190GB-16/,
      ).to_stderr
    end

    context "custom dir & type XML" do
      let(:out) { "dir" }
      let(:format) { "xml" }

      it "fetch" do
        expect { RelatonNist::DataFetcher.fetch(output: "dir", format: "xml") }.to output(
          /File dir\/NIST_SP_1190GB-16\.xml exists\. Docid: NIST SP 1190GB-16/,
        ).to_stderr
      end

      it "fetch" do
        expect { RelatonNist::DataFetcher.fetch(output: out, format: "bibxml") }.to output(
          /File dir\/NIST_SP_1190GB-16\.xml exists\. Docid: NIST SP 1190GB-16/,
        ).to_stderr
      end
    end
  end

  it "raise an HTTP error" do
    expect(OpenURI).to receive(:open_uri).and_raise StandardError.new("Test error")
    expect { RelatonNist::DataFetcher.fetch }
      .to output(/Test error/).to_stderr
  end

  it "riase parsing error" do
    expect(OpenURI).to receive(:open_uri).with(RelatonNist::DataFetcher::URL).and_return nist_data
    expect(RelatonNist::NistBibliographicItem).to receive(:new).and_raise(StandardError).twice
    expect { RelatonNist::DataFetcher.fetch }
      .to output(/Document: 10.6028\/NIST.SP\.800-133r1/).to_stderr
  end

  context "parse document" do
    subject { RelatonNist::DataFetcher.new "dir", "xml" }

    it "fetch contributors" do
      doc = Nokogiri::XML File.read("spec/examples/report-paper.xml", encoding: "UTF-8")
      rep = doc.at "/report-paper_metadata"
      contribs = subject.fetch_contributor rep
      expect(contribs.size).to eq 3
      expect(contribs[0][:entity]).to be_instance_of(RelatonBib::Person)
      expect(contribs[0][:entity].name.forename[0].content).to eq "David"
      expect(contribs[0][:entity].name.surname.content).to eq "Waltermire"
    end
  end
end
