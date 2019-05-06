module Relaton
  class Processor end
end

require "relaton/processor"

RSpec.describe NistBib::XMLParser do
  it "create item from xml" do
    xml = File.read "spec/examples/get.xml", encoding: "UTF-8"
    item = Relaton::NistBib::Processor.new.from_xml xml
    expect(item.to_xml).to be_equivalent_to xml 
  end

  it "create item from xml with commentperiod" do
    xml = File.read "spec/examples/draft.xml", encoding: "UTF-8"
    item = Relaton::NistBib::Processor.new.from_xml xml
    expect(item.to_xml).to be_equivalent_to xml 
  end
end
