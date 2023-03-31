describe RelatonNist::PubsExport do
  subject { RelatonNist::PubsExport.instance }

  before { Singleton.__init__(RelatonNist::PubsExport) }
  after { Singleton.__init__(RelatonNist::PubsExport) }

  context "update json file" do
    it "when ctime is nil" do
      VCR.use_cassette "json_data" do
        expect(File).to receive(:exist?).with(RelatonNist::PubsExport::DATAFILE).at_most(:once).and_return true
        allow(File).to receive(:exist?).and_call_original
        expect(File).to receive(:ctime).and_return(nil).at_most(1).time
        item = subject.data.find { |i| i["docidentifier"] == "SP 800-205 (Draft)" }
        expect(item).to be_instance_of Hash
      end
    end

    it "when size of file is zero" do
      expect(File).to receive(:exist?).with(RelatonNist::PubsExport::DATAFILE).and_return true
      ctime = Time.now
      expect(File).to receive(:ctime).with(RelatonNist::PubsExport::DATAFILE).and_return ctime
      expect(File).to receive(:size).with(RelatonNist::PubsExport::DATAFILE).and_return 0
      expect(subject).to receive(:fetch_data).with(ctime)
      subject.data
    end
  end

  it "thread safe fetch data" do
    expect(File).to receive(:exist?).with(RelatonNist::PubsExport::DATAFILE).and_return false
    expect(subject).to receive(:fetch_data).with(nil)
    expect(subject).to receive(:unzip) do
      sleep 0.1
      [{ "docidentifier" => "SP 800-205 (Draft)" }]
    end
    threads = (1..2).map do
      Thread.new { Thread.current[:data] = subject.data }
    end
    threads.each &:join
    threads.each do |t|
      expect(t[:data]).to eq [{ "docidentifier" => "SP 800-205 (Draft)" }]
    end
  end
end
