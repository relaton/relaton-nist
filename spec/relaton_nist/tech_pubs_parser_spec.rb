describe RelatonNist::TechPubsParser do
  it "initialize" do
    dp = described_class.new :doc, :series
    expect(dp.instance_variable_get(:@doc)).to eq :doc
    expect(dp.instance_variable_get(:@series)).to eq :series
  end

  it "create instance & call parse" do
    dp = double "parser"
    expect(dp).to receive(:parse).and_return :bibitem
    expect(described_class).to receive(:new).with(:doc, :series).and_return dp
    expect(described_class.parse(:doc, :series)).to eq :bibitem
  end

  context "instance methods" do
    let(:doc) { double "doc" }
    subject { RelatonNist::TechPubsParser.new(doc, :series) }
    before { allow(doc).to receive(:[]).with("language").and_return "en" }

    context "#parse" do
      it "success" do
        expect(subject).to receive(:args).and_return arg: "value"
        expect(RelatonNist::NistBibliographicItem).to receive(:new).with(
          type: "standard", language: ["en"], script: ["Latn"], doctype: "standard", arg: "value",
        ).and_return :bibitem
        expect(subject.parse).to eq :bibitem
      end

      it "error warn" do
        expect(doc).to receive(:at).with("doi").and_return double(text: "10.6028/NIST.IR.5394v1")
        expect(subject).to receive(:args).and_raise StandardError
        expect { subject.parse }.to output(/Document: `10.6028\/NIST\.IR.5394v1`/).to_stderr
      end
    end

    it "#args" do
      expect(subject).to receive(:parse_docid).and_return :docid
      expect(subject).to receive(:parse_date).and_return :date
      expect(subject).to receive(:parse_contributor).and_return :contributor
      expect(subject).to receive(:parse_edition).and_return :edition
      expect(subject).to receive(:parse_docstatus).and_return :docstatus
      expect(subject).to receive(:parse_title).and_return :title
      expect(subject).to receive(:parse_link).and_return :link
      expect(subject).to receive(:parse_abstract).and_return :abstract
      expect(subject).to receive(:parse_place).and_return :place
      expect(subject).to receive(:parse_series).and_return :series
      expect(subject).to receive(:parse_relation).and_return :relation
      expect(subject.args).to eq(
        docid: :docid, date: :date, contributor: :contributor, edition: :edition,
        abstract: :abstract, docstatus: :docstatus, title: :title, link: :link,
        place: :place, series: :series, relation: :relation
      )
    end

    it "#parse_docid" do
      expect(subject).to receive(:pub_id).and_return "NIST IR 5394v1"
      expect(subject).to receive(:doi).and_return "10.6028/NIST.IR.5394v1"
      docid = subject.parse_docid
      expect(docid).to be_instance_of Array
      expect(docid.size).to eq 2
      expect(docid[0]).to be_instance_of RelatonBib::DocumentIdentifier
      expect(docid[0].id).to eq "NIST IR 5394v1"
      expect(docid[0].type).to eq "NIST"
      expect(docid[0].primary).to be true
      expect(docid[1].id).to eq "10.6028/NIST.IR.5394v1"
      expect(docid[1].type).to eq "DOI"
    end

    it "#pub_id" do
      expect(subject).to receive(:doi).and_return "10.6028/NIST.IR.5394v1"
      expect(subject.pub_id).to eq "NIST IR 5394v1"
    end

    context "#doi" do
      shared_examples "fetch DOI" do |doi, result|
        before { allow(doc).to receive(:at).with("doi_data/doi").and_return double(text: doi)}
        it { expect(subject.doi).to eq result }
      end

      it_behaves_like "fetch DOI", "10.6028/NBS.CIRC.e2e", "10.6028/NBS.CIRC.2e2"
      it_behaves_like "fetch DOI", "10.6028/NBS.CIRC.sup", "10.6028/NBS.CIRC.24e7sup"
      it_behaves_like "fetch DOI", "10.6028/NBS.CIRC.supJun1925-Jun1926", "10.6028/NBS.CIRC.24e7sup2"
      it_behaves_like "fetch DOI", "10.6028/NBS.CIRC.supJun1925-Jun1927", "10.6028/NBS.CIRC.24e7sup3"
      it_behaves_like "fetch DOI", "10.6028/NBS.CIRC.24supJuly1922", "10.6028/NBS.CIRC.24e6sup"
      it_behaves_like "fetch DOI", "10.6028/NBS.CIRC.24supJan1924", "10.6028/NBS.CIRC.24e6sup2"
      it_behaves_like "fetch DOI", "10.6028/NIST.IR.8323", "10.6028/NIST.IR.8323"
    end

    context "#parse_title" do
      it do
        titles = [double(text: "Title"), double(text: "Subtitle")]
        expect(doc).to receive(:xpath).with("titles/title|titles/subtitle").and_return titles
        title = subject.parse_title
        expect(title).to be_instance_of Array
        expect(title.size).to eq 1
        expect(title[0]).to eq content: "Title\nSubtitle", format: "text/plain", language: "en", script: "Latn"
      end

      it "no titles" do
        expect(doc).to receive(:xpath).with("titles/title|titles/subtitle").and_return []
        expect(subject.parse_title).to be_empty
      end
    end

    it "#parse_link" do
      res = double(text: "https://nvlpubs.nist.gov/nistpubs/ir/2021/NIST.IR.8323.pdf")
      expect(doc).to receive(:at).with("doi_data/resource").and_return res
      expect(subject).to receive(:doi).and_return "10.6028/NIST.IR.8323"
      link = subject.parse_link
      expect(link).to be_a Array
      expect(link.size).to eq 2
      expect(link[0].type).to eq "doi"
      expect(link[0].content.to_s).to eq "https://doi.org/10.6028/NIST.IR.8323"
      expect(link[1].type).to eq "pdf"
      expect(link[1].content.to_s).to eq "https://nvlpubs.nist.gov/nistpubs/ir/2021/NIST.IR.8323.pdf"
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
        subject.instance_variable_set(:@doc, doc)
        abstract = subject.parse_abstract
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
        subject.instance_variable_set(:@doc, doc)
        expect(subject.parse_abstract.size).to eq 0
      end
    end

    it "#parse_date" do
      report = Nokogiri::XML <<~XML
        <report-paper_metadata>
          <publication_date media_type="online">
            <month>02</month>
            <year>2013</year>
          </publication_date>
          <approval_date>
            <month>06</month>
            <day>03</day>
            <year>2020</year>
          </approval_date>
        </report-paper_metadata>
      XML
      doc = report.at("/report-paper_metadata")
      subject.instance_variable_set(:@doc, doc)
      date = subject.parse_date
      expect(date).to be_instance_of Array
      expect(date.size).to eq 2
      expect(date[0]).to be_instance_of RelatonBib::BibliographicDate
      expect(date[0].type).to eq "published"
      expect(date[0].on).to eq "2013-02"
      expect(date[1].type).to eq "confirmed"
      expect(date[1].on).to eq "2020-06-03"
    end

    context "#parse_edition" do
      it do
        expect(doc).to receive(:at).with("edition_number").and_return double(text: "2")
        expect(subject.parse_edition).to eq "2"
      end

      it "no edition" do
        expect(doc).to receive(:at).with("edition_number").and_return nil
        expect(subject.parse_edition).to be_nil
      end
    end

    it "#parse_contributor" do
      person = { "contributor_role" => "author" }
      expect(doc).to receive(:xpath).with("contributors/person_name").and_return [person]
      expect(doc).to receive(:xpath).with("publisher").and_return [:org]
      expect(subject).to receive(:fullname).with(person).and_return :fullname
      expect(subject).to receive(:affiliation).and_return :affiliation
      expect(subject).to receive(:create_org).with(:org).and_return :organization
      contribs = subject.parse_contributor
      expect(contribs.size).to eq 2
      expect(contribs[0][:entity]).to be_instance_of RelatonBib::Person
      expect(contribs[0][:entity].name).to eq :fullname
      expect(contribs[0][:entity].affiliation).to eq :affiliation
      expect(contribs[0][:role][0][:type]).to eq "author"
      expect(contribs[1][:entity]).to be :organization
      expect(contribs[1][:role][0][:type]).to eq "publisher"
    end

    it "#fullname" do
      person = Nokogiri::XML(<<~XML).at("/person_name")
        <person_name>
          <given_name>John</given_name>
          <surname>Doe</surname>
          <ORCID>https://orcid.org/0000-0002-1825-0097</ORCID>
        </person_name>
      XML
      expect(subject).to receive(:forename_initial).with(person).and_return [:fname, :initials]
      expect(subject).to receive(:localized_string).with("Doe").and_return :surname
      expect(RelatonBib::PersonIdentifier).to receive(:new)
        .with("orcid", "https://orcid.org/0000-0002-1825-0097").and_return(:ident)
      expect(RelatonBib::FullName).to receive(:new).with(
        surname: :surname, forename: :fname, initials: :initials, identifier: [:ident],
      ).and_return :fullname
      expect(subject.fullname(person)).to be :fullname
    end

    it "#affiliation" do
      doc = Nokogiri::XML <<~XML
        <report-paper_metadata>
          <institution>
            <institution_department>Information Technology Laboratory</institution_department>
          </institution>
        </report-paper_metadata>
      XML
      subject.instance_variable_set(:@doc, doc.at("/report-paper_metadata"))
      affiliation = subject.affiliation
      expect(affiliation).to be_instance_of Array
      expect(affiliation.size).to eq 1
      expect(affiliation[0]).to be_instance_of RelatonBib::Affiliation
      expect(affiliation[0].organization).to be_instance_of RelatonBib::Organization
      expect(affiliation[0].organization.name[0].content).to eq "Information Technology Laboratory"
    end

    context "#forename_initial" do
      it "create forename & initials" do
        person = Nokogiri::XML(<<~XML).at("/person_name")
          <person_name>
            <given_name>Ira H. A.</given_name>
            <surname>Woolson</surname>
          </person_name>
        XML
        expect(subject).to receive(:forename).with("Ira", "H").and_return :fname
        expect(subject).to receive(:forename).with(nil, "A").and_return :fname
        expect(subject).to receive(:localized_string).with("H. A.").and_return :initials
        expect(subject.forename_initial(person)).to eq([%i[fname fname], :initials])
      end

      it "create forename only" do
        person = Nokogiri::XML(<<~XML).at("/person_name")
          <person_name>
            <given_name>Ira</given_name>
            <surname>Woolson</surname>
          </person_name>
        XML
        expect(subject).to receive(:forename).with("Ira").and_return :fname
        expect(subject.forename_initial(person)).to eq([[:fname], nil])
      end

      it "don't create initials with empty content" do
        person = double "person"
        node = double "node", text: ""
        expect(person).to receive(:at).with("given_name").and_return node
        fns, inits = subject.forename_initial person
        expect(fns).to be_empty
        expect(inits).to be_nil
      end

      it "don't create initials with nil content" do
        person = double "person"
        expect(person).to receive(:at).with("given_name").and_return nil
        fns, inits = subject.forename_initial person
        expect(fns).to be_empty
        expect(inits).to be_nil
      end
    end

    context "#forename" do
      it "create forename" do
        fn = subject.forename "Ira", "H"
        expect(fn).to be_instance_of RelatonBib::Forename
        expect(fn.content).to eq "Ira"
        expect(fn.language).to eq ["en"]
        expect(fn.script).to eq ["Latn"]
        expect(fn.initial).to eq "H"
      end

      it "create forename with nil content" do
        fn = subject.forename nil, "H"
        expect(fn).to be_instance_of RelatonBib::Forename
        expect(fn.content).to be_nil
      end

      it "create forename without inials" do
        fn = subject.forename "Ira"
        expect(fn).to be_instance_of RelatonBib::Forename
        expect(fn.initial).to be_nil
      end

      it "do not create" do
        expect(subject.forename(nil, nil)).to be_nil
        expect(subject.forename("", "")).to be_nil
      end
    end

    it "#create_org" do
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

    it "#parse_relation" do
      doc = Nokogiri::XML <<~XML
        <report-paper_metadata>
          <program xmlns="http://www.crossref.org/relations.xsd">
            <related_item>
              <intra_work_relation relationship-type="hasPreprint" identifier-type="doi">10.6028/NIST.IR.8323</intra_work_relation>
            </related_item>
            <related_item>
              <inter_work_relation relationship-type="isPartOf" identifier-type="doi">10.6028/NIST.SP.800-213</inter_work_relation>
            </related_item>
          </program>
        </report-paper_metadata>
      XML
      subject.instance_variable_set(:@doc, doc.at("/report-paper_metadata"))
      rel = subject.parse_relation
      expect(rel).to be_a Array
      expect(rel.size).to eq 2
      expect(rel[0]).to be_instance_of Hash
      expect(rel[0][:type]).to eq "hasReprint"
      expect(rel[0][:bibitem]).to be_instance_of RelatonBib::BibliographicItem
      expect(rel[0][:bibitem].docidentifier[0].id).to eq "NIST IR 8323"
      expect(rel[0][:bibitem].docidentifier[0].type).to eq "NIST"
      expect(rel[0][:bibitem].docidentifier[0].primary).to eq true
      expect(rel[0][:bibitem].formattedref.content).to eq "NIST IR 8323"
      expect(rel[1][:type]).to eq "partOf"
      expect(rel[1][:bibitem].docidentifier[0].id).to eq "NIST SP 800-213"
    end

    context "#parse_docstatus" do
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
        subject.instance_variable_set :@doc, doc.at("/report-paper_metadata")
        status = subject.parse_docstatus
        expect(status).to be_instance_of RelatonBib::DocumentStatus
        expect(status.stage).to be_instance_of RelatonBib::DocumentStatus::Stage
        expect(status.stage.value).to eq "preprint"
      end

      it "no status" do
        expect(doc).to receive(:at).with(
          "./ns:program/ns:related_item/ns:*[@relationship-type='isPreprintOf']",
          ns: "http://www.crossref.org/relations.xsd",
        ).and_return nil
        expect(subject.parse_docstatus).to be_nil
      end
    end

    it "#parse_place" do
      doc = Nokogiri::XML <<~XML
        <report-paper_metadata>
          <institution>
            <institution_place>City, ST</institution_place>
          </institution>
        </report-paper_metadata>
      XML
      subject.instance_variable_set(:@doc, doc.at("/report-paper_metadata"))
      expect(subject.parse_place).to eq ["City, ST"]
    end

    it "fetch series" do
      seires = YAML.load_file File.expand_path("series.yaml", "lib/relaton_nist")
      subject.instance_variable_set(:@series, seires)
      expect(subject).to receive(:pub_id).and_return "NIST CSWP 09102018"
      series = subject.parse_series
      expect(series).to be_a Array
      expect(series.size).to eq 1
      expect(series[0].title).to be_instance_of RelatonBib::TypedTitleString
      expect(series[0].title.title.content).to eq "NIST Cybersecurity White Papers"
      expect(series[0].abbreviation).to be_instance_of RelatonBib::LocalizedString
      expect(series[0].abbreviation.content).to eq "CSWP"
      expect(series[0].number).to eq "09102018"
    end

    it "localzes string" do
      ls = subject.localized_string("Content")
      expect(ls).to be_instance_of RelatonBib::LocalizedString
      expect(ls.content).to eq "Content"
    end
  end
end
