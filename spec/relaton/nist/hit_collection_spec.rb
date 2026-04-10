RSpec.describe Relaton::Nist::HitCollection do
  subject { Relaton::Nist::HitCollection.new "NIST IR 8200" }

  it "raise error when HTTP response isn't 200 or 404" do
    io = double "OpenURI IO", status: ["500"]
    error = OpenURI::HTTPError.new("", io)
    expect(Relaton::Index).to receive(:find_or_create).and_raise error
    expect { subject.send(:from_ga) }.to raise_error error
  end

  it "sort hits" do
    expect(subject).to receive(:from_json).and_return [
      Relaton::Nist::Hit.new({ status: "withdrawn", code: "B", release_date: Date.today }, subject),
      Relaton::Nist::Hit.new({ status: "draft", code: "A", release_date: Date.today }, subject),
    ]
    subj = subject.search
    expect(subj).to be subject
  end

  it "sort_hits! prefers higher /Upd for the same base code" do
    hits = [
      Relaton::Nist::Hit.new({ code: "NIST FIPS 140-2",      release_date: Date.new(2001, 5, 25) }, subject),
      Relaton::Nist::Hit.new({ code: "NIST FIPS 140-2/Upd1", release_date: Date.new(2001, 10, 10) }, subject),
      Relaton::Nist::Hit.new({ code: "NIST FIPS 140-2/Upd2", release_date: Date.new(2002, 12, 3) }, subject),
    ]
    subject.instance_variable_set :@array, hits
    subject.send :sort_hits!
    expect(subject.array.map { |h| h.hit[:code] }).to eq [
      "NIST FIPS 140-2/Upd2",
      "NIST FIPS 140-2/Upd1",
      "NIST FIPS 140-2",
    ]
  end

  it "sort_hits! keeps distinct base codes in alphabetical order" do
    hits = [
      Relaton::Nist::Hit.new({ code: "NIST SP 800-12r1", release_date: Date.new(2017, 6, 22) }, subject),
      Relaton::Nist::Hit.new({ code: "NIST SP 800-12",   release_date: Date.new(1995, 10, 2) }, subject),
    ]
    subject.instance_variable_set :@array, hits
    subject.send :sort_hits!
    expect(subject.array.first.hit[:code]).to eq "NIST SP 800-12"
  end

  describe "#pubs_export_id" do
    let(:hc) { Relaton::Nist::HitCollection.new "NIST FIPS 140-2" }

    def call(json)
      hc.send(:pubs_export_id, json)
    end

    it "final iteration => no stage" do
      expect(call(
        "doi" => "10.6028/NIST.FIPS.140-2",
        "docidentifier" => "FIPS 140-2",
        "uri" => "https://csrc.nist.gov/pubs/fips/140-2/final",
        "iteration" => "final",
      )).to eq "NIST FIPS 140-2"
    end

    it "final iteration with /upd2/final URI => no stage, update set" do
      expect(call(
        "doi" => "10.6028/NIST.FIPS.140-2",
        "docidentifier" => "FIPS 140-2",
        "uri" => "https://csrc.nist.gov/pubs/fips/140-2/upd2/final",
        "iteration" => "final",
      )).to eq "NIST FIPS 140-2/Upd2"
    end

    it "ipd iteration => ipd stage" do
      expect(call(
        "doi" => "10.6028/NIST.SP.800-189.ipd",
        "docidentifier" => "SP 800-189",
        "uri" => "https://csrc.nist.gov/pubs/sp/800/189/ipd",
        "iteration" => "ipd",
      )).to match(/ipd$/)
    end

    it "fpd iteration => fpd stage" do
      expect(call(
        "doi" => "10.6028/NIST.SP.800-189.fpd",
        "docidentifier" => "SP 800-189",
        "uri" => "https://csrc.nist.gov/pubs/sp/800/189/fpd",
        "iteration" => "fpd",
      )).to match(/fpd$/)
    end

    it "2pd iteration => 2pd stage" do
      expect(call(
        "doi" => "10.6028/NIST.SP.800-189.2pd",
        "docidentifier" => "SP 800-189",
        "uri" => "https://csrc.nist.gov/pubs/sp/800/189/2pd",
        "iteration" => "2pd",
      )).to match(/2pd$/)
    end

    it "URI ipd overrides DOI fpd and iteration final" do
      expect(call(
        "doi" => "10.6028/NIST.SP.800-157r1.fpd",
        "docidentifier" => "SP 800-157 Rev. 1",
        "uri" => "https://csrc.nist.gov/pubs/sp/800/157/r1/ipd",
        "iteration" => "final",
      )).to match(/ipd$/)
    end

    it "nil iteration and no stage in URI => no stage" do
      expect(call(
        "doi" => "10.6028/NIST.FIPS.140-2",
        "docidentifier" => "FIPS 140-2",
        "uri" => "https://csrc.nist.gov/pubs/fips/140-2/final",
        "iteration" => nil,
      )).to eq "NIST FIPS 140-2"
    end
  end
end
