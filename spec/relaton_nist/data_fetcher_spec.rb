RSpec.describe "NIST documents fetcher" do
  subject { RelatonNist::DataFetcher.new "data", "yaml" }

  let(:nist_data) do
    File.read "spec/examples/nist_data.xml", encoding: "UTF-8"
  end

  context "instance methods" do
    it "#index" do
      expect(subject.index).to be_instance_of Relaton::Index::Type
    end
  end

  context "fetch data" do
    let(:out) { "data" }
    let(:format) { "yaml" }

    before(:each) do
      expect(OpenURI).to receive(:open_uri).with(RelatonNist::DataFetcher::URL).and_return nist_data
      # expect(Dir).to receive(:exist?).with(out).and_return false
      expect(FileUtils).to receive(:mkdir_p).with(out)
      files = ["#{out}/NIST_SP_800-133R1.#{format}", "#{out}/NIST_SP_1190GB-16.#{format}"]
      expect(Dir).to receive(:[]).with("#{out}/*.#{format}").and_return files
      expect(FileUtils).to receive(:rm).with(files)
      # expect(File).to receive(:exist?).with(files[0]).and_return false
      # expect(File).to receive(:exist?).with(files[1]).and_return true
      expect(File).to receive(:write).with(files[0], kind_of(String), encoding: "UTF-8")
      expect(File).to receive(:write).with(files[1], kind_of(String), encoding: "UTF-8")
    end

    subject do
      fetcher = RelatonNist::DataFetcher.new out, format
      fetcher.instance_variable_get(:@files) << "#{out}/NIST_SP_1190GB-16.#{format}"
      fetcher
    end

    it "fetch" do
      expect(subject.index).to receive(:save)
      expect { subject.fetch }.to output(
        /File data\/NIST_SP_1190GB-16\.yaml exists\. Docid: NIST SP 1190GB-16/,
      ).to_stderr
    end

    context "custom dir & type XML" do
      let(:out) { "dir" }
      let(:format) { "xml" }

      it "fetch" do
        expect(subject.index).to receive(:save)
        expect { subject.fetch }.to output(
          /File dir\/NIST_SP_1190GB-16\.xml exists\. Docid: NIST SP 1190GB-16/,
        ).to_stderr
      end

      it "fetch" do
        subject.instance_variable_set :@format, "bibxml"
        expect(subject.index).to receive(:save)
        expect { subject.fetch }.to output(
          /File dir\/NIST_SP_1190GB-16\.xml exists\. Docid: NIST SP 1190GB-16/,
        ).to_stderr
      end
    end
  end

  it "raise HTTP error" do
    expect(OpenURI).to receive(:open_uri).and_raise StandardError.new("Test error")
    expect { RelatonNist::DataFetcher.fetch }
      .to output(/Test error/).to_stderr
  end

  it "raise parsing error" do
    expect(FileUtils).to receive(:mkdir_p).with("data")
    expect(OpenURI).to receive(:open_uri).with(RelatonNist::DataFetcher::URL).and_return nist_data
    expect(RelatonNist::NistBibliographicItem).to receive(:new).and_raise(StandardError).twice
    expect(subject.index).to receive(:save)
    expect { subject.fetch }
      .to output(/Document: 10.6028\/NIST.SP\.800-133r1/).to_stderr
  end

  context "parse document" do
    subject { RelatonNist::DataFetcher.new "dir", "xml" }
    let(:rep) do
      doc = Nokogiri::XML File.read("spec/examples/report-paper.xml", encoding: "UTF-8")
      doc.at "/report-paper_metadata"
    end

    it "fetch title" do
      title = subject.fetch_title rep
      expect(title).to eq [{
        content: "Transitioning to the Security Content Automation Protocol (SCAP) Version 2",
        format: "text/plain",
        language: "en",
        script: "Latn",
      }]
    end

    it "fetch contributors" do
      contribs = subject.fetch_contributor rep
      expect(contribs.size).to eq 3
      expect(contribs[0][:entity]).to be_instance_of(RelatonBib::Person)
      expect(contribs[0][:entity].name.initials.content).to eq "D"
      expect(contribs[0][:entity].name.forename[0].initial).to eq "D"
      expect(contribs[0][:entity].name.surname.content).to eq "Waltermire"
      expect(contribs[1][:entity].name.forename[0].content).to eq "Jessica"
      expect(contribs[1][:entity].name.surname.content).to eq "Fitzgerald-McKay"
    end

    it "don't create initials with empty content" do
      person = double "person"
      node = double "node", text: ""
      expect(person).to receive(:at).with("given_name").and_return node
      doc = { language: "en" }
      fns, inits = subject.forename_initial person, doc
      expect(fns).to be_empty
      expect(inits).to be_nil
    end

    it "don't create initials with nil content" do
      person = double "person"
      expect(person).to receive(:at).with("given_name").and_return nil
      doc = { language: "en" }
      fns, inits = subject.forename_initial person, doc
      expect(fns).to be_empty
      expect(inits).to be_nil
    end

    it "create publisher organization" do
      doc = Nokogiri::XML <<~XML
        <report-paper_metadata>
          <publisher>
            <publisher_name>Publisher</publisher_name>
          </publisher>
          <institution>
            <institution_name>Publisher</institution_name>
            <institution_place>City, ST</institution_place>
          </institution>
        </report-paper_metadata>
      XML
      pub = doc.at "/report-paper_metadata/publisher"
      publisher = subject.create_org pub
      expect(publisher).to be_instance_of(RelatonBib::Organization)
      expect(publisher.name[0].content).to eq "Publisher"
      expect(publisher.contact[0].city).to eq "City"
      expect(publisher.contact[0].state).to eq "ST"
      expect(publisher.contact[0].country).to eq "US"
    end

    it "fetch link" do
      link = subject.fetch_link rep
      expect(link).to be_a Array
      expect(link.size).to eq 2
      expect(link[0].type).to eq "doi"
      expect(link[0].content.to_s).to eq "https://doi.org/10.6028/NIST.CSWP.09102018"
      expect(link[1].type).to eq "pdf"
      expect(link[1].content.to_s).to eq "https://nvlpubs.nist.gov/nistpubs/CSWP/NIST.CSWP.09102018.pdf"
    end

    it "fetch series" do
      series = subject.fetch_series rep
      expect(series).to be_a Array
      expect(series.size).to eq 1
      expect(series[0].title).to be_instance_of RelatonBib::TypedTitleString
      expect(series[0].title.title.content).to eq "NIST Cybersecurity White Papers"
      expect(series[0].abbreviation).to be_instance_of RelatonBib::LocalizedString
      expect(series[0].abbreviation.content).to eq "CSWP"
      expect(series[0].number).to eq "09102018"
    end

    it "fetch relation" do
      rel = subject.fetch_relation rep
      expect(rel).to be_a Array
      expect(rel.size).to eq 2
      expect(rel[0]).to be_instance_of Hash
      expect(rel[0][:type]).to eq "obsoletes"
      expect(rel[0][:bibitem]).to be_instance_of RelatonBib::BibliographicItem
      expect(rel[0][:bibitem].docidentifier[0].id).to eq "NIST SP 800-133"
      expect(rel[0][:bibitem].docidentifier[0].type).to eq "NIST"
      expect(rel[0][:bibitem].docidentifier[0].primary).to eq true
      expect(rel[0][:bibitem].formattedref.content).to eq "NIST SP 800-133"
    end

    context "#fetch_satatus" do
      it "preprint" do
        doc = Nokogiri::XML <<~XML
          <report-paper_metadata>
            <program xmlns="http://www.crossref.org/relations.xsd">
              <related_item>
                <intra_work_relation relationship-type="isPreprintOf" identifier-type="doi">10.6028/NIST.IR.8323</intra_work_relation>
              </related_item>
            </program>
          </report-paper_metadata>
        XML
        pub = doc.at "/report-paper_metadata"
        status = subject.fetch_status(pub)
        expect(status).to be_instance_of RelatonBib::DocumentStatus
        expect(status.stage).to be_instance_of RelatonBib::DocumentStatus::Stage
        expect(status.stage.value).to eq "preprint"
      end

      it { expect(subject.fetch_status(rep)).to be_nil }
    end

    context "fetch DOI" do
      shared_examples "fetch DOI" do |doi, result|
        it do
          report = Nokogiri::XML <<~XML
            <report-paper_metadata>
              <doi_data>
                <doi>#{doi}</doi>
              </doi_data>
            </report-paper_metadata>
          XML
          doc = report.at("/report-paper_metadata")
          expect(subject.fetch_doi(doc)).to eq result
        end
      end

      it_behaves_like "fetch DOI", "10.6028/NBS.CIRC.e2e", "10.6028/NBS.CIRC.2e2"
      it_behaves_like "fetch DOI", "10.6028/NBS.CIRC.sup", "10.6028/NBS.CIRC.24e7sup"
      it_behaves_like "fetch DOI", "10.6028/NBS.CIRC.supJun1925-Jun1926", "10.6028/NBS.CIRC.24e7sup2"
      it_behaves_like "fetch DOI", "10.6028/NBS.CIRC.supJun1925-Jun1927", "10.6028/NBS.CIRC.24e7sup3"
      it_behaves_like "fetch DOI", "10.6028/NBS.CIRC.24supJuly1922", "10.6028/NBS.CIRC.24e6sup"
      it_behaves_like "fetch DOI", "10.6028/NBS.CIRC.24supJan1924", "10.6028/NBS.CIRC.24e6sup2"
    end

    context "fetch abstract" do
      it do
        report = Nokogiri::XML <<~XML
          <report-paper_metadata language="en">
            <jats:abstract xmlns:jats="http://www.ncbi.nlm.nih.gov/JATS1">
              <jats:p>Abstract</jats:p>
            </jats:abstract>
          </report-paper_metadata>
        XML
        doc = report.at("/report-paper_metadata")
        abstract = subject.fetch_abstract doc
        expect(abstract).to be_instance_of Array
        expect(abstract.size).to eq 1
        expect(abstract[0]).to be_instance_of RelatonBib::FormattedString
        expect(abstract[0].content).to eq "Abstract"
        expect(abstract[0].language).to eq ["en"]
        expect(abstract[0].script).to eq ["Latn"]
      end

      it "ignore abstract with no content" do
        report = Nokogiri::XML <<~XML
          <report-paper_metadata>
            <jats:abstract xmlns:jats="http://www.ncbi.nlm.nih.gov/JATS1">
              <jats:p/>
            </jats:abstract>
          </report-paper_metadata>
        XML
        doc = report.at("/report-paper_metadata")
        expect(subject.fetch_abstract(doc).size).to eq 0
      end

      it "#pub_id" do
        doc = Nokogiri::XML(<<~XML).at("/report-paper_metadata")
          <report-paper_metadata>
            <doi_data>
              <doi>10.6028/nist.ir.8011-4</doi>
            </doi_data>
          </report-paper_metadata>
        XML
        expect(subject.pub_id(doc)).to eq "NIST IR 8011-4"
      end
    end
  end
end
