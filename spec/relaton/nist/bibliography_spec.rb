RSpec.describe Relaton::Nist::Bibliography do
  it "raise error when search" do
    expect(Relaton::Nist::HitCollection).to receive(:new).and_raise SocketError
    expect do
      Relaton::Nist::Bibliography.search("NISTIR 7831")
    end.to raise_error Relaton::RequestError
  end

  describe ".parse_iteration" do
    subject { described_class.send(:parse_iteration, stage) }

    context "with 'IPD'" do
      let(:stage) { "IPD" }

      it { is_expected.to eq "1" }
    end

    context "with 'FPD'" do
      let(:stage) { "FPD" }

      it { is_expected.to eq "final" }
    end

    context "with '2PD'" do
      let(:stage) { "2PD" }

      it { is_expected.to eq "2" }
    end

    context "with 'PD-F'" do
      let(:stage) { "PD-F" }

      it { is_expected.to eq "final" }
    end

    context "with nil" do
      let(:stage) { nil }

      it { is_expected.to be_nil }
    end
  end

  describe ".match_date?" do
    let(:bib_date_class) { Relaton::Bib::Date }

    def make_item(dates)
      item = double("item")
      allow(item).to receive(:date).and_return(dates)
      item
    end

    it "returns true when a date's at matches" do
      d = bib_date_class.new(type: "published", at: "2020-06-15")
      item = make_item([d])
      result = described_class.send(:match_date?, item, Date.new(2020, 6, 15))
      expect(result).to be true
    end

    it "returns true when a date's from matches" do
      d = bib_date_class.new(type: "published", from: "2021-03-01")
      item = make_item([d])
      result = described_class.send(:match_date?, item, Date.new(2021, 3, 1))
      expect(result).to be true
    end

    it "returns false when no dates match" do
      d = bib_date_class.new(type: "published", at: "2020-01-01")
      item = make_item([d])
      result = described_class.send(:match_date?, item, Date.new(2022, 12, 31))
      expect(result).to be false
    end
  end

  describe ".match_year?" do
    let(:bib_date_class) { Relaton::Bib::Date }

    def make_item(dates)
      item = double("item")
      allow(item).to receive(:date).and_return(dates)
      item
    end

    it "returns the year when it matches" do
      d = bib_date_class.new(type: "published", at: "2020-06-15")
      item = make_item([d])
      result = described_class.send(:match_year?, item, "2020")
      expect(result).to eq 2020
    end

    it "yields missed years when they don't match" do
      d = bib_date_class.new(type: "published", at: "2019-03-01")
      item = make_item([d])
      missed = []
      result = described_class.send(:match_year?, item, "2020") { |y| missed << y }
      expect(result).to be_nil
      expect(missed).to eq [2019]
    end

    it "returns nil when no date values exist" do
      d = bib_date_class.new(type: "published")
      item = make_item([d])
      result = described_class.send(:match_year?, item, "2020")
      expect(result).to be_nil
    end

    it "ignores non-published/issued date types" do
      d = bib_date_class.new(type: "created", at: "2020-06-15")
      item = make_item([d])
      result = described_class.send(:match_year?, item, "2020")
      expect(result).to be_nil
    end
  end
end
