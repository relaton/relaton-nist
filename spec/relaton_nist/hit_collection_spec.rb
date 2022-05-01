RSpec.describe RelatonNist::HitCollection do
  subject { RelatonNist::HitCollection.new "REF"}

  context "update json file" do
    it "when ctime is nil" do
      VCR.use_cassette "json_data" do
        expect(File).to receive(:exist?).with(RelatonNist::HitCollection::DATAFILE).at_most(:once).and_return true
        expect(File).to receive(:exist?).and_call_original.at_most(3).times
        expect(File).to receive(:ctime).and_return(nil).at_most(1).time
        result = RelatonNist::NistBibliography.get "SP 800-205 (February 2019) (PD)"
        expect(result.id).to eq "SP800-205(Draft)"
      end
    end

    it "when size of file is zero" do
      hc = RelatonNist::HitCollection.new "REF"
      expect(File).to receive(:exist?).with(RelatonNist::HitCollection::DATAFILE).and_return true
      ctime = Time.now
      expect(File).to receive(:ctime).with(RelatonNist::HitCollection::DATAFILE).and_return ctime
      expect(File).to receive(:size).with(RelatonNist::HitCollection::DATAFILE).and_return 0
      expect(hc).to receive(:fetch_data).with(ctime)
      hc.send :data
    end
  end

  it "raise error when HTTP response isn't 200 or 404" do
    expect(subject).to receive(:from_json).and_return []
    io = double "OpenURI IO", status: ["500"]
    error = OpenURI::HTTPError.new("", io)
    expect(OpenURI).to receive(:open_uri).and_raise error
    expect { subject.search({}) }.to raise_error error
  end

  it "sort hits" do
    expect(subject).to receive(:from_json).and_return [
      RelatonNist::Hit.new({ status: "withdrawn"}, subject),
      RelatonNist::Hit.new({ status: "draft"}, subject),
    ]
    subj = subject.search({})
    expect(subj).to be subject
  end
end
