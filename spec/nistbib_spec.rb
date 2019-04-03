RSpec.describe NistBib do
  it "has a version number" do
    expect(NistBib::VERSION).not_to be nil
  end

  it "fetch hit" do
    VCR.use_cassette '8200' do
      hit_collection = NistBib::NistBibliography.search('8200', '2018')
      expect(hit_collection.fetched).to be_falsy
      expect(hit_collection.fetch).to be_instance_of NistBib::HitCollection
      expect(hit_collection.fetched).to be_truthy
      expect(hit_collection.first).to be_instance_of NistBib::Hit
    end
  end

  it 'return xml of hit' do
    VCR.use_cassette '8011' do
      hits = NistBib::NistBibliography.search('8011')
      file_path = 'spec/examples/hit.xml'
      File.write file_path, hits.first.to_xml unless File.exist? file_path
      expect(hits.first.to_xml).to be_equivalent_to File.open(file_path, "r:UTF-8", &:read).sub(/2019-02-05/, Date.today.to_s)
    end
  end

  it 'return string of hit' do
    VCR.use_cassette '8200' do
      hits = NistBib::NistBibliography.search('8200', '2018').fetch
      expect(hits.first.to_s).to eq '<NistBib::Hit:'\
        "#{format('%#.14x', hits.first.object_id << 1)} "\
        '@text="8200" @fetched="true" @fullIdentifier="NISTIR 8200:2018" '\
        '@title="8200">'
    end
  end

  it 'return string of hit collection' do
    VCR.use_cassette '8200' do
      hits = NistBib::NistBibliography.search('8200', '2018').fetch
      expect(hits.to_s).to eq '<NistBib::HitCollection:'\
        "#{format('%#.14x', hits.object_id << 1)} "\
        '@fetched=true>'
    end
  end

  it 'get a code' do
    VCR.use_cassette '8200' do
      result = NistBib::NistBibliography.get('8200', '2018', {}).to_xml
      file_path = 'spec/examples/get.xml'
      File.write file_path, result unless File.exist? file_path
      expect(result).to be_equivalent_to File.open(file_path, "r:UTF-8", &:read).sub(/2019-02-06/, Date.today.to_s)
    end
  end

  it 'get a reference with an year in a code' do
    VCR.use_cassette '8200_2017' do
      result = NistBib::NistBibliography.get('NISTIR 8200:2018').to_xml
      expect(result).to include '<on>2018</on>'
    end
  end

  it 'get DRAFT' do
    VCR.use_cassette 'draft' do
      result = NistBib::NistBibliography.get('800-189', nil, {}).to_xml
      file_path = 'spec/examples/draft.xml'
      File.write file_path, result unless File.exist? file_path
      expect(result).to be_equivalent_to File.open(file_path, "r:UTF-8", &:read).gsub(/2019-02-06/, Date.today.to_s)
    end
  end

  it 'get RETIRED DRAFT' do
    VCR.use_cassette 'retired_draft' do
      result = NistBib::NistBibliography.get('7831', nil, {}).to_xml
      file_path = 'spec/examples/retired_draft.xml'
      File.write file_path, result unless File.exist? file_path
      expect(result).to be_equivalent_to File.open(file_path, "r:UTF-8", &:read).gsub(/2019-02-06/, Date.today.to_s)
    end
  end

  it "warns when a code matches a resource but the year does not" do
    VCR.use_cassette '8200_wrong_year' do
      expect { NistBib::NistBibliography.get('8200', '2017', {}) }.to output(
        "fetching 8200...\nWARNING: no match found online for 8200:2017. "\
        "The code must be exactly like it is on the standards website.\n"\
        "If you wanted to cite all document parts for the reference, use \"8200 (all parts)\".\n"\
        "If the document is not a standard, use its document type abbreviation (TS, TR, PAS, Guide).\n"
      ).to_stderr
    end
  end

  it 'search failed' do
    VCR.use_cassette 'failed' do
      expect { NistBib::NistBibliography.get('2222', nil, {}) }.to output(
        "fetching 2222...\n"\
        "WARNING: no match found online for 2222. The code must be exactly like it is on the standards website.\n"\
        "If you wanted to cite all document parts for the reference, use \"2222 (all parts)\".\n"\
        "If the document is not a standard, use its document type abbreviation (TS, TR, PAS, Guide).\n"
      ).to_stderr
    end
  end
end
