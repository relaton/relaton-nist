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
end
