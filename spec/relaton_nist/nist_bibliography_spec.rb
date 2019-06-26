RSpec.describe RelatonNist::NistBibliography do
  it "raise error when search" do
    expect(OpenURI).to receive(:open_uri).and_raise SocketError
    expect do
      RelatonNist::NistBibliography.get("NISTIR 7831")
    end.to raise_error RelatonBib::RequestError
  end
end
