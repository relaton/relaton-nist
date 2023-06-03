RSpec.describe RelatonNist::NistBibliography do
  it "raise error when search" do
    expect(RelatonNist::HitCollection).to receive(:new).and_raise SocketError
    expect do
      RelatonNist::NistBibliography.search("NISTIR 7831")
    end.to raise_error RelatonBib::RequestError
  end
end
