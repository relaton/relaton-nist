RSpec.describe NistBib do
  it "has a version number" do
    expect(NistBib::VERSION).not_to be nil
  end

  it "fetch hit" do
    VCR.use_cassette '8200' do
      hit_collection = NistBib::NistBibliography.search('8200')
      expect(hit_collection.fetched).to be_falsy
      expect(hit_collection.fetch).to be_instance_of NistBib::HitCollection
      expect(hit_collection.fetched).to be_truthy
      expect(hit_collection.first).to be_instance_of NistBib::Hit
    end
  end

  it 'return xml of hit' do
    VCR.use_cassette '8200' do
      hits = NistBib::NistBibliography.search('8200')
      file_path = 'spec/examples/hit.xml'
      File.write file_path, hits.first.to_xml unless File.exist? file_path
      expect(hits.first.to_xml).to be_equivalent_to File.read(file_path).sub(/2018-10-26/, Date.today.to_s)
    end
  end
end
