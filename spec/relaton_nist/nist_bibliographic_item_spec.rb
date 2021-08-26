require "yaml"

RSpec.describe RelatonNist::NistBibliographicItem do
  it "returns hash" do
    hash = YAML.load_file "spec/examples/nist_bib_item.yml"
    item_hash = RelatonNist::HashConverter.hash_to_bib hash
    item = RelatonNist::NistBibliographicItem.new(**item_hash)
    hash["fetched"] = Date.today.to_s
    expect(item.to_hash).to eq hash
  end
end
