require "yaml"

RSpec.describe RelatonNist::NistBibliographicItem do
  let(:hash) { YAML.load_file "spec/examples/nist_bib_item.yml" }

  subject do
    item_hash = RelatonNist::HashConverter.hash_to_bib hash
    RelatonNist::NistBibliographicItem.new(**item_hash)
  end

  it "returns hash" do
    expect(subject.to_h).to eq hash
  end

  it "render BibXML" do
    file = "spec/examples/nist_bibxml.xml"
    xml = subject.to_bibxml
    File.write file, xml, encoding: "UTF-8" unless File.exist? file
    expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
  end

  it "ref_attrs" do
    attrs = subject.ref_attrs
    expect(attrs[:anchor]).to eq "NIST.IR.8011.Vol.3"
  end
end
