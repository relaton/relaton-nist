RSpec.describe RelatonNist::HitCollection do
  it "update json file" do
    VCR.use_cassette "json_data" do
      expect(File).to receive(:ctime).and_return nil
      result = RelatonNist::NistBibliography.get "SP 800-205 (February 2019) (PD)"
      expect(result.id).to eq "SP800-205(DRAFT)"
    end
  end
end
