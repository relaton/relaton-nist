module Relaton
  class Processor end
end

require "relaton/processor"

RSpec.describe NistBib::XMLParser do
  it "create item from xml" do
    xml = File.read "spec/examples/get.xml", encoding: "UTF-8"
    item = Relaton::NistBib::Processor.new.from_xml xml
    expect(item.to_xml(bibdata: true)).to be_equivalent_to xml
  end

  it "create item from xml with commentperiod" do
    xml = File.read "spec/examples/draft.xml", encoding: "UTF-8"
    item = Relaton::NistBib::Processor.new.from_xml xml
    expect(item.to_xml(bibdata: true)).to be_equivalent_to xml
  end

  it "get document" do
    VCR.use_cassette "8200" do
      item = Relaton::NistBib::Processor.new.get "8200", "2018"
      expect(item.docidentifier.first.id).to eq "NISTIR 8200"
    end
  end
end