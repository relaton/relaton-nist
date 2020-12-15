RSpec.describe RelatonNist::HitCollection do
  it "update json file" do
    VCR.use_cassette "json_data" do
      expect(File).to receive(:exist?).with("/Users/andrej/.relaton/nist/pubs-export.zip").at_most(:once).and_return true
      expect(File).to receive(:exist?).and_call_original.at_most(3).times
      expect(File).to receive(:ctime).and_return(nil).at_most(1).time
      result = RelatonNist::NistBibliography.get "SP 800-205 (February 2019) (PD)"
      expect(result.id).to eq "SP800-205(Draft)"
    end
  end
end
