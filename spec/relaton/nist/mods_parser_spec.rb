require "relaton/nist/mods_parser"

describe Relaton::Nist::ModsParser do
  it "initialize" do
    doc = double "doc"
    series = double "series"
    parser = described_class.new doc, series
    expect(parser.instance_variable_get(:@doc)).to eq doc
    expect(parser.instance_variable_get(:@series)).to eq series
  end

  context "instance methods" do
    let(:doc) do
      xml = File.read "spec/fixtures/allrecords-MODS.xml", encoding: "UTF-8"
      LocMods::Collection.from_xml(xml).mods[0]
    end

    subject do
      described_class.new doc, double(:series)
    end

    it "parse" do
      expect(subject).to receive(:parse_docidentifier).and_return "docidentifier"
      expect(subject).to receive(:parse_title).and_return "title"
      expect(subject).to receive(:parse_source).and_return "source"
      expect(subject).to receive(:parse_abstract).and_return "abstract"
      expect(subject).to receive(:parse_date).and_return "date"
      expect(subject).to receive(:parse_doctype).and_return :doctype
      expect(subject).to receive(:parse_contributor).and_return "contributor"
      expect(subject).to receive(:parse_relation).and_return "relation"
      expect(subject).to receive(:parse_place).and_return "place"
      expect(subject).to receive(:parse_series).and_return "series"
      expect(Relaton::Nist::ItemData).to receive(:new).with(
        type: "standard", docidentifier: "docidentifier", title: "title",
        source: "source", abstract: "abstract", date: "date",
        contributor: "contributor", relation: "relation", place: "place",
        series: "series", ext: an_instance_of(Relaton::Nist::Ext),
      )
      subject.parse
    end

    it "parse_docid" do
      docid = subject.parse_docidentifier
      expect(docid).to be_instance_of Array
      expect(docid.size).to eq 2
      expect(docid[0]).to be_instance_of Relaton::Bib::Docidentifier
      expect(docid[0].type).to eq "NIST"
      expect(docid[0].content).to eq "NIST IR 6229"
      expect(docid[0].primary).to be true
      expect(docid[1].type).to eq "DOI"
      expect(docid[1].content).to eq "NIST.IR.6229"
    end

    context "pub_id" do
      it { expect(subject.pub_id).to eq "NIST IR 6229" }

      shared_examples "parse IDs from MODS" do |doi, pub_id|
        it doi do
          doc.location[0].url[0].content = "https://doi.org/10.6028/#{doi}"
          expect(subject.pub_id).to eq pub_id
        end
      end

      it_behaves_like "parse IDs from MODS", "NIST.HB.135e2022-upd1", "NIST HB 135e2022/Upd1-202205"
      it_behaves_like "parse IDs from MODS", "NIST.IR.8170-upd", "NIST IR 8170/Upd1-202003"
      it_behaves_like "parse IDs from MODS", "NIST.AMS.300-8r1/upd", "NIST AMS 300-8r1/Upd1-202102"
      it_behaves_like "parse IDs from MODS", "NIST.IR.8259Apt", "NIST IR 8259A por"
      it_behaves_like "parse IDs from MODS", "nbs.tn.671", "NBS TN 671"
      it_behaves_like "parse IDs from MODS", "NBS.CIRC.supJun1925-Jun1926", "NBS CIRC 24e7sup2"
      it_behaves_like "parse IDs from MODS", "NIST.MONO.1-1b", "NIST MONO 1-1B"
    end

    context "replace_wrong_doi" do
      shared_examples "replace doi" do |orig_doi, fixed_doi|
        it orig_doi do
          expect(subject.replace_wrong_doi(orig_doi)).to eq fixed_doi
        end
      end

      it_behaves_like "replace doi", "NBS.CIRC.sup", "NBS.CIRC.24e7sup"
      it_behaves_like "replace doi", "NBS.CIRC.supJun1925-Jun1926", "NBS.CIRC.24e7sup2"
      it_behaves_like "replace doi", "NBS.CIRC.supJun1925-Jun1927", "NBS.CIRC.24e7sup3"
      it_behaves_like "replace doi", "NBS.CIRC.24supJuly1922", "NBS.CIRC.24e6sup"
      it_behaves_like "replace doi", "NBS.CIRC.24supJan1924", "NBS.CIRC.24e6sup2"
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
        expect(titles[0]).to be_instance_of Relaton::Bib::Title
        expect(titles[0].content).to eq "The OOF Manual"
        expect(titles[0].type).to eq "title-main"
        expect(titles[0].language).to eq "en"
        expect(titles[0].script).to eq "Latn"
        expect(titles[1].content).to eq "version 1.0"
        expect(titles[1].type).to eq "title-part"
        expect(titles[2].content).to eq "The OOF Manual - version 1.0"
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
        expect(titles[0]).to be_instance_of Relaton::Bib::Title
        expect(titles[0].content).to eq "Fire Dynamics Simulator (Version 5) Technical Reference Guide"
        expect(titles[0].type).to eq "main"
        expect(titles[0].language).to eq "en"
        expect(titles[0].script).to eq "Latn"
      end
    end

    it "parse_source" do
      links = subject.parse_source
      expect(links).to be_instance_of Array
      expect(links.size).to eq 1
      expect(links.first).to be_instance_of Relaton::Bib::Uri
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
      expect(abstracts.first).to be_instance_of Relaton::Bib::LocalizedMarkedUpString
      expect(abstracts.first.content).to include "The lean flammability limit"
      expect(abstracts.first.language).to eq "en"
      expect(abstracts.first.script).to eq "Latn"
    end

    it "parse_date" do
      dates = subject.parse_date
      expect(dates).to be_instance_of Array
      expect(dates.size).to eq 1
      expect(dates[0]).to be_instance_of Relaton::Nist::Date
      expect(dates[0].at.to_s).to eq "1998"
      expect(dates[0].type).to eq "issued"
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
      expect(type).to be_instance_of Relaton::Nist::Doctype
      expect(type.content).to eq "standard"
    end

    context "parse_contributor" do
      it "with default role" do
        contribs = subject.parse_contributor
        expect(contribs).to be_instance_of Array
        expect(contribs.size).to eq 4
        expect(contribs[0]).to be_instance_of Relaton::Bib::Contributor
        expect(contribs[0].role[0].type).to eq "author"
        expect(contribs[0].person).to be_instance_of Relaton::Bib::Person
        expect(contribs[0].person.name.completename.content).to eq "Grosshandler, William Lytle."
        expect(contribs[0].person.identifier).to be_instance_of Array
        expect(contribs[0].person.identifier[0].type).to eq "uri"
        expect(contribs[0].person.identifier[0].content).to eq "https://id.loc.gov/authorities/names/n86864993"
        expect(contribs[1].role[0].type).to eq "author"
        expect(contribs[1].person.name.completename.content).to eq "Donnelly, Michelle."
        expect(contribs[2].role[0].type).to eq "author"
        expect(contribs[2].person.name.completename.content).to eq "Womeldorf, Carole."
        expect(contribs[3].organization).to be_instance_of Relaton::Bib::Organization
        expect(contribs[3].role[0].type).to eq "publisher"
        expect(contribs[3].organization.name.first.content).to eq "National Institute of Standards and Technology (U.S.)"
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
        expect(contribs[0]).to be_instance_of Relaton::Bib::Contributor
        expect(contribs[0].role[0].type).to eq "editor"
        expect(contribs[0].person).to be_instance_of Relaton::Bib::Person
        expect(contribs[0].person.name.completename.content).to eq "Ricker, Richard E.,"
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
        org = subject.create_org doc.mods[0].name[0]
        expect(org).to be_instance_of Relaton::Bib::Organization
        expect(org.name.first.content).to eq "National Institute of Standards and Technology (U.S.)"
        expect(org.identifier).to be_instance_of Array
        expect(org.identifier[0].type).to eq "uri"
        expect(org.identifier[0].content).to eq "https://id.loc.gov/authorities/names/n79021383"
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
        expect(relations[0]).to be_instance_of Relaton::Nist::Relation
        expect(relations[0].type).to eq "updates"
        expect(relations[0].bibitem.docidentifier[0].content).to eq "NIST TN 2025"
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
        expect(relations[0]).to be_instance_of Relaton::Nist::Relation
        expect(relations[0].type).to eq "updatedBy"
        expect(relations[0].bibitem.docidentifier[0].content).to eq "NIST HB 135e2022"
      end
    end

    it "parse_place" do
      place = subject.parse_place
      expect(place).to be_instance_of Array
      expect(place.size).to eq 1
      expect(place[0]).to be_instance_of Relaton::Bib::Place
      expect(place[0].city).to eq "Gaithersburg"
      expect(place[0].region[0].iso).to eq "MD"
    end

    context "create_region" do
      it "with valid state" do
        region = subject.create_region "MD"
        expect(region).to be_instance_of Array
        expect(region.size).to eq 1
        expect(region[0].iso).to eq "MD"
      end

      it "with invalid state" do
        region = subject.create_region "XX"
        expect(region).to be_instance_of Array
        expect(region.size).to eq 1
        expect(region[0].iso).to eq "XX"
      end
    end

    it "parse_series" do
      series = subject.parse_series
      expect(series).to be_instance_of Array
      expect(series.size).to eq 1
      expect(series[0]).to be_instance_of Relaton::Bib::Series
      expect(series[0].title[0].content).to eq "NISTIR; NIST IR; NIST interagency report; NIST internal report"
      expect(series[0].number).to eq "6229"
    end
  end
end
