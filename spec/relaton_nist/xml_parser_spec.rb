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

  # it "warn if XML doesn't have bibitem or bibdata element" do
  #   item = ""
  #   expect { item = RelatonNist::XMLParser.from_xml "" }.to output(/WARN: Can't find bibitem/)
  #     .to_stderr
  #   expect(item).to be_nil
  # end
end
