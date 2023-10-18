RSpec.describe RelatonNist::HitCollection do
  subject { RelatonNist::HitCollection.new "NIST IR 8200" }

  it "raise error when HTTP response isn't 200 or 404" do
    io = double "OpenURI IO", status: ["500"]
    error = OpenURI::HTTPError.new("", io)
    expect(Relaton::Index).to receive(:find_or_create).and_raise error
    expect { subject.send(:from_ga) }.to raise_error error
  end

  it "sort hits" do
    expect(subject).to receive(:from_json).and_return [
      RelatonNist::Hit.new({ status: "withdrawn" }, subject),
      RelatonNist::Hit.new({ status: "draft" }, subject),
    ]
    subj = subject.search
    expect(subj).to be subject
  end
end
