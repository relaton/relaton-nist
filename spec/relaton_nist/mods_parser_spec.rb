describe RelatonNist::ModsParser do
  it "initialize" do
    doc = double "doc"
    series = double "series"
    parser = described_class.new doc, series
    expect(parser.instance_variable_get(:@doc)).to eq doc
    expect(parser.instance_variable_get(:@series)).to eq series
  end

  context "instance methods" do
    let(:collection) do
      xml = File.read "spec/examples/allrecords-MODS.xml", encoding: "UTF-8"
      LocMods::Collection.from_xml xml
    end

    subject do
      described_class.new collection.mods[0], double(:series)
    end

    it "parse" do
      expect(subject).to receive(:parse_docid).and_return "docid"
      expect(subject).to receive(:parse_title).and_return "title"
      expect(subject).to receive(:parse_link).and_return "link"
      expect(subject).to receive(:parse_abstract).and_return "abstract"
      expect(subject).to receive(:parse_date).and_return "date"
      expect(subject).to receive(:parse_doctype).and_return "doctype"
      expect(subject).to receive(:parse_contributor).and_return "contributor"
      expect(subject).to receive(:parse_relation).and_return "relation"
      expect(subject).to receive(:parse_place).and_return "place"
      expect(subject).to receive(:parse_series).and_return "series"
      expect(RelatonNist::NistBibliographicItem).to receive(:new).with(
        type: "standard", docid: "docid", title: "title", link: "link",
        abstract: "abstract", date: "date", doctype: "doctype",
        contributor: "contributor", relation: "relation", place: "place",
        series: "series"
      )
      subject.parse
    end

    it "parse_docid" do
      expect(subject).to receive(:pub_id).and_return "pub_id"
      expect(subject).to receive(:doi).and_return "doi"
      expect(RelatonBib::DocumentIdentifier).to receive(:new).with(type: "NIST", id: "pub_id", primary: true)
      expect(RelatonBib::DocumentIdentifier).to receive(:new).with(type: "DOI", id: "doi")
      subject.parse_docid
    end

    it "pub_id" do
      expect(subject.pub_id).to eq "NIST IR 6229"
    end

    context "doi" do
      it { expect(subject.doi).to eq "10.6028/NIST.IR.6229" }

      shared_examples "fix doi" do |url, fixed_doi|
        it "10.6028/NBS.CIRC.sup" do
          doc = subject.instance_variable_get :@doc
          expect(doc.location[0].url[0]).to receive(:content).and_return url
          expect(subject.doi).to eq fixed_doi
        end
      end

      it_behaves_like "fix doi", "https://doi.org/10.6028/NBS.CIRC.sup", "10.6028/NBS.CIRC.24e7sup"
      it_behaves_like "fix doi", "https://doi.org/10.6028/NBS.CIRC.supJun1925-Jun1926", "10.6028/NBS.CIRC.24e7sup2"
      it_behaves_like "fix doi", "https://doi.org/10.6028/NBS.CIRC.supJun1925-Jun1927", "10.6028/NBS.CIRC.24e7sup3"
      it_behaves_like "fix doi", "https://doi.org/10.6028/NBS.CIRC.24supJuly1922", "10.6028/NBS.CIRC.24e6sup"
      it_behaves_like "fix doi", "https://doi.org/10.6028/NBS.CIRC.24supJan1924", "10.6028/NBS.CIRC.24e6sup2"
    end

    context "parse_title" do
      it "with title and subtitle" do
        doc = LocMods::Collection.from_xml <<~XML
          <modsCollection xmlns="http://www.loc.gov/mods/v3">
            <mods>
              <titleInfo>
                <nonSort xml:space="preserve">The  </nonSort>
                <title>OOF Manual</title>
                <subTitle>version 1.0</subTitle>
              </titleInfo>
            </mods>
          </modsCollection>
        XML
        subject.instance_variable_set :@doc, doc.mods[0]
        titles = subject.parse_title
        expect(titles).to be_instance_of Array
        expect(titles.size).to eq 3
        expect(titles[0]).to be_instance_of RelatonBib::TypedTitleString
        expect(titles[0].title.content).to eq "The OOF Manual"
        expect(titles[0].type).to eq "title-main"
        expect(titles[0].title.language).to eq ["en"]
        expect(titles[0].title.script).to eq ["Latn"]
        expect(titles[1].title.content).to eq "version 1.0"
        expect(titles[1].type).to eq "title-part"
        expect(titles[2].title.content).to eq "The OOF Manual - version 1.0"
        expect(titles[2].type).to eq "main"
      end

      it "with title only" do
        doc = LocMods::Collection.from_xml <<~XML
          <modsCollection xmlns="http://www.loc.gov/mods/v3">
            <mods>
              <titleInfo>
                <title>Fire Dynamics Simulator (Version 5) Technical Reference Guide</title>
              </titleInfo>
            </mods>
          </modsCollection>
        XML
        subject.instance_variable_set :@doc, doc.mods[0]
        titles = subject.parse_title
        expect(titles).to be_instance_of Array
        expect(titles.size).to eq 1
        expect(titles[0]).to be_instance_of RelatonBib::TypedTitleString
        expect(titles[0].title.content).to eq "Fire Dynamics Simulator (Version 5) Technical Reference Guide"
        expect(titles[0].type).to eq "main"
        expect(titles[0].title.language).to eq ["en"]
        expect(titles[0].title.script).to eq ["Latn"]
      end
    end

    it "parse_link" do
      links = subject.parse_link
      expect(links).to be_instance_of Array
      expect(links.size).to eq 1
      expect(links.first).to be_instance_of RelatonBib::TypedUri
      expect(links.first.content.to_s).to eq "https://doi.org/10.6028/NIST.IR.6229"
      expect(links.first.type).to eq "doi"
    end

    it "parse_abstract" do
      doc = LocMods::Collection.from_xml <<~XML
        <modsCollection xmlns="http://www.loc.gov/mods/v3">
          <mods>
            <abstract>
              The lean flammability limit as a fundamental refrigerant property is defined as the minimum
            </abstract>
          </mods>
        </modsCollection>
      XML
      parser = described_class.new doc.mods[0], double(:series)
      abstracts = parser.parse_abstract
      expect(abstracts).to be_instance_of Array
      expect(abstracts.size).to eq 1
      expect(abstracts.first).to be_instance_of RelatonBib::FormattedString
      expect(abstracts.first.content).to include "The lean flammability limit"
      expect(abstracts.first.language).to eq ["en"]
      expect(abstracts.first.script).to eq ["Latn"]
    end

    it "parse_date" do
      dates = subject.parse_date
      expect(dates).to be_instance_of Array
      expect(dates.size).to eq 1
      expect(dates[0]).to be_instance_of RelatonBib::BibliographicDate
      expect(dates[0].on).to eq "1998"
      expect(dates[0].type).to eq "issued"
      # expect(dates[1].on).to eq "2019-09-12"
      # expect(dates[1].type).to eq "created"
      # expect(dates[2].on).to eq "2020-01-14"
      # expect(dates[2].type).to eq "updated"
    end

    context "decode_date" do
      it "marc with 6 digits" do
        date = double "date", encoding: "marc", content: "191121"
        expect(subject.decode_date date).to eq "2019-11-21"
      end

      it "iso8601" do
        date = double "date", encoding: "iso8601", content: "20200114084155."
        expect(subject.decode_date date).to eq "2020-01-14"
      end
    end

    it "parse_doctype" do
      type = subject.parse_doctype
      expect(type).to be_instance_of RelatonBib::DocumentType
      expect(type.type).to eq "standard"
    end

    context "parse_contributor" do
      it "with default role" do
        contribs = subject.parse_contributor
        expect(contribs).to be_instance_of Array
        expect(contribs.size).to eq 4
        expect(contribs[0]).to be_instance_of RelatonBib::ContributionInfo
        expect(contribs[0].role[0].type).to eq "author"
        expect(contribs[0].entity).to be_instance_of RelatonBib::Person
        expect(contribs[0].entity.name.completename.content).to eq "Grosshandler, William Lytle."
        expect(contribs[0].entity.identifier).to be_instance_of Array
        expect(contribs[0].entity.identifier[0].type).to eq "uri"
        expect(contribs[0].entity.identifier[0].value).to eq "https://id.loc.gov/authorities/names/n86864993"
        expect(contribs[1].role[0].type).to eq "author"
        expect(contribs[1].entity.name.completename.content).to eq "Donnelly, Michelle."
        expect(contribs[2].role[0].type).to eq "author"
        expect(contribs[2].entity.name.completename.content).to eq "Womeldorf, Carole."
        expect(contribs[3].entity).to be_instance_of RelatonBib::Organization
        expect(contribs[3].role[0].type).to eq "publisher"
        expect(contribs[3].entity.name.first.content).to eq "National Institute of Standards and Technology (U.S.)"
      end

      it "with role" do
        doc = LocMods::Collection.from_xml <<~XML
          <modsCollection xmlns="http://www.loc.gov/mods/v3">
            <mods>
              <name type="personal">
                <namePart>Ricker, Richard E.,</namePart>
                <role>
                  <roleTerm type="text">editor</roleTerm>
                </role>
              </name>
            </mods>
          </modsCollection>
        XML
        subject.instance_variable_set :@doc, doc.mods[0]
        contribs = subject.parse_contributor
        expect(contribs).to be_instance_of Array
        expect(contribs.size).to eq 1
        expect(contribs[0]).to be_instance_of RelatonBib::ContributionInfo
        expect(contribs[0].role[0].type).to eq "editor"
        expect(contribs[0].entity).to be_instance_of RelatonBib::Person
        expect(contribs[0].entity.name.completename.content).to eq "Ricker, Richard E.,"
      end
    end

    context "create_org" do
      it "with indentifier" do
        doc = LocMods::Collection.from_xml <<~XML
          <modsCollection xmlns="http://www.loc.gov/mods/v3">
            <mods>
              <name type="corporate">
                <namePart>National Institute of Standards and Technology (U.S.)</namePart>
                <nameIdentifier>https://id.loc.gov/authorities/names/n79021383</nameIdentifier>
              </name>
            </mods>
          </modsCollection>
        XML
        # subject.instance_variable_set :@doc, doc.mods[0]
        org = subject.create_org doc.mods[0].name[0]
        expect(org).to be_instance_of RelatonBib::Organization
        expect(org.name.first.content).to eq "National Institute of Standards and Technology (U.S.)"
        expect(org.identifier).to be_instance_of Array
        expect(org.identifier[0].type).to eq "uri"
        expect(org.identifier[0].value).to eq "https://id.loc.gov/authorities/names/n79021383"
      end
    end

    context "parse_relation" do
      it "with name" do
        doc = LocMods::Collection.from_xml <<~XML
          <modsCollection xmlns="http://www.loc.gov/mods/v3">
            <mods>
              <relatedItem type="preceding">
                <name>
                  <namePart>10.6028/NIST.TN.2025</namePart>
                </name>
              </relatedItem>
            </mods>
          </modsCollection>
        XML
        subject.instance_variable_set :@doc, doc.mods[0]
        relations = subject.parse_relation
        expect(relations).to be_instance_of Array
        expect(relations.size).to eq 1
        expect(relations[0]).to be_instance_of RelatonBib::DocumentRelation
        expect(relations[0].type).to eq "updates"
        expect(relations[0].bibitem.docidentifier[0].id).to eq "NIST TN 2025"
      end

      it "with other type" do
        doc = LocMods::Collection.from_xml <<~XML
          <modsCollection xmlns="http://www.loc.gov/mods/v3">
            <mods>
              <relatedItem type="succeeding" otherType="10.6028/NIST.HB.135e2022"/>
            </mods>
          </modsCollection>
        XML
        subject.instance_variable_set :@doc, doc.mods[0]
        relations = subject.parse_relation
        expect(relations).to be_instance_of Array
        expect(relations.size).to eq 1
        expect(relations[0]).to be_instance_of RelatonBib::DocumentRelation
        expect(relations[0].type).to eq "updatedBy"
        expect(relations[0].bibitem.docidentifier[0].id).to eq "NIST HB 135e2022"
      end
    end

    it "parse_place" do
      place = subject.parse_place
      expect(place).to be_instance_of Array
      expect(place.size).to eq 1
      expect(place[0].city).to eq "Gaithersburg"
      expect(place[0].region[0].iso).to eq "MD"
      expect(place[0].region[0].name).to eq "Maryland"
    end

    context "create_region" do
      it "with valid state" do
        region = subject.create_region "MD"
        expect(region).to be_instance_of Array
        expect(region.size).to eq 1
        expect(region[0].iso).to eq "MD"
        expect(region[0].name).to eq "Maryland"
      end

      it "with invalid state" do
        region = subject.create_region "XX"
        expect(region).to be_empty
      end
    end

    it "parse_series" do
      series = subject.parse_series
      expect(series).to be_instance_of Array
      expect(series.size).to eq 1
      expect(series[0]).to be_instance_of RelatonBib::Series
      expect(series[0].title.title.content).to eq "NISTIR; NIST IR; NIST interagency report; NIST internal report"
      expect(series[0].number).to eq "6229"
    end
  end
end
