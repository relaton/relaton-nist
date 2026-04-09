describe Relaton::Nist::PubsExport do
  subject { Relaton::Nist::PubsExport.instance }

  before do
    Singleton.__init__(Relaton::Nist::PubsExport)
    $ignore_pubs_export = false # rubocop:disable Style/GlobalVars
  end

  after do
    Singleton.__init__(Relaton::Nist::PubsExport)
    $ignore_pubs_export = true # rubocop:disable Style/GlobalVars
  end

  context "update json file" do
    it "when ctime is nil" do
      VCR.use_cassette "json_data" do
        expect(File).to receive(:exist?).with(Relaton::Nist::PubsExport::DATAFILE).at_most(:once).and_return true
        allow(File).to receive(:exist?).and_call_original
        expect(File).to receive(:ctime).and_return(nil).at_most(1).time
        item = subject.data.find { |i| i["docidentifier"] == "FIPS 140-2" }
        expect(item).to be_instance_of Hash
      end
    end

    it "when size of file is zero" do
      expect(File).to receive(:exist?).with(Relaton::Nist::PubsExport::DATAFILE).and_return true
      ctime = Time.now
      expect(File).to receive(:ctime).with(Relaton::Nist::PubsExport::DATAFILE).and_return ctime
      expect(File).to receive(:size).with(Relaton::Nist::PubsExport::DATAFILE).and_return 0
      expect(subject).to receive(:fetch_data).with(ctime)
      subject.data
    end
  end

  it "returns last modified time from server" do
    last_modified = "Thu, 09 Apr 2026 12:00:00 GMT"
    stub_request(:head, "#{Relaton::Nist::PubsExport::PUBS_EXPORT}.meta")
      .to_return(headers: { "Last-Modified" => last_modified })
    expect(subject.send(:last_modified)).to eq Time.httpdate(last_modified)
  end

  it "thread safe fetch data" do
    expect(File).to receive(:exist?).with(Relaton::Nist::PubsExport::DATAFILE).and_return false
    expect(subject).to receive(:fetch_data).with(nil)
    expect(subject).to receive(:unzip) do
      sleep 0.1
      [{ "docidentifier" => "SP 800-205 (Draft)" }]
    end
    threads = (1..2).map do
      Thread.new { Thread.current[:data] = subject.data }
    end
    threads.each(&:join)
    threads.each do |t|
      expect(t[:data]).to eq [{ "docidentifier" => "SP 800-205 (Draft)" }]
    end
  end
end
