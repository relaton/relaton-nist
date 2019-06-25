RSpec.describe RelatonNist::NistBibliography do
  it "raise error when search" do
    expect(OpenURI).to receive(:open_uri).and_raise SocketError
    expect { RelatonNist::NistBibliography.get("NISTIR 7831") }.to output(
      "fetching NISTIR 7831...\n"\
      "Could not access https://www.nist.gov\n"\
      "WARNING: no match found online for NISTIR 7831. "\
      "The code must be exactly like it is on the standards website.\n",
    ).to_stderr
  end
end