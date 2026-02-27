RSpec.describe Relaton::Nist::Scraper do
  # it "raise connection error" do
  #   expect do
  #     expect(Net::HTTP).to receive(:get_response).and_raise SocketError
  #     Relaton::Nist::Scraper.parse_page url: "www.nist.gov"
  #   end.to raise_error Relaton::RequestError
  # end

  # it "make docid from a title" do
  #   hit_data = {
  #     json: {
  #       "docidentifier" => "DOC 1",
  #       "authors" => [],
  #       "editors" => [],
  #       "supersedes" => [],
  #       "superseded-by" => [],
  #       "keywords" => [],
  #     },
  #     title: "Test title",
  #   }
  #   bib = Relaton::Nist::Scraper.parse_json hit_data
  #   expect(bib.docidentifier[0].content)
  # end
end
