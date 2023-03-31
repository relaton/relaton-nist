RSpec.describe RelatonNist::HitCollection do
  subject { RelatonNist::HitCollection.new "REF" }

  it "raise error when HTTP response isn't 200 or 404" do
    expect(subject).to receive(:from_json).and_return []
    io = double "OpenURI IO", status: ["500"]
    error = OpenURI::HTTPError.new("", io)
    expect(OpenURI).to receive(:open_uri).and_raise error
    expect { subject.search }.to raise_error error
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
