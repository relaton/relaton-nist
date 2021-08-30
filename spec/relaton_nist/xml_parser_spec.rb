module Relaton
  # class Processor end
end

RSpec.describe RelatonNist::XMLParser do
  it "create item from xml" do
    xml = File.read "spec/examples/get.xml", encoding: "UTF-8"
    item = RelatonNist::XMLParser.from_xml xml
    expect(item.to_xml(bibdata: true)).to be_equivalent_to xml
  end

  it "create item from xml with commentperiod" do
    xml = File.read "spec/examples/draft.xml", encoding: "UTF-8"
    item = RelatonNist::XMLParser.from_xml xml
    expect(item.to_xml(bibdata: true)).to be_equivalent_to xml
  end

  it "get document" do
    VCR.use_cassette "8200" do
      item = RelatonNist::NistBibliography.get "NISTIR 8200", "2018"
      expect(item.docidentifier.first.id).to eq "NIST IR 8200"
    end
  end

  it "warn if XML doesn't have bibitem or bibdata element" do
    item = ""
    expect { item = RelatonNist::XMLParser.from_xml "" }.to output(/can't find bibitem/)
      .to_stderr
    expect(item).to be_nil
  end
end
