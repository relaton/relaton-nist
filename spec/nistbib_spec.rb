RSpec.describe NistBib do
  it "has a version number" do
    expect(NistBib::VERSION).not_to be nil
  end

  it "fetch hit" do
    VCR.use_cassette "8200" do
      hit_collection = NistBib::NistBibliography.search("8200", "2018")
      expect(hit_collection.fetched).to be_falsy
      expect(hit_collection.fetch).to be_instance_of NistBib::HitCollection
      expect(hit_collection.fetched).to be_truthy
      expect(hit_collection.first).to be_instance_of NistBib::Hit
    end
  end

  context "return xml of hit" do
    it "with bibdata root elemen" do
      VCR.use_cassette "8011" do
        hits = NistBib::NistBibliography.search("8011")
        file_path = "spec/examples/hit.xml"
        File.write file_path, hits.first.to_xml(bibdata: true) unless File.exist? file_path
        expect(hits.first.to_xml(bibdata: true)).to be_equivalent_to File.
          open(file_path, "r:UTF-8", &:read).
          gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
      end
    end

    it "with bibitem root elemen" do
      VCR.use_cassette "8011" do
        hits = NistBib::NistBibliography.search("8011")
        file_path = "spec/examples/hit_bibitem.xml"
        File.write file_path, hits.first.to_xml unless File.exist? file_path
        expect(hits.first.to_xml).to be_equivalent_to File.
          open(file_path, "r:UTF-8", &:read).
          gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
      end
    end
  end

  it "return string of hit" do
    VCR.use_cassette "8200" do
      hits = NistBib::NistBibliography.search("8200", "2018").fetch
      expect(hits.first.to_s).to eq "<NistBib::Hit:"\
        "#{format('%#.14x', hits.first.object_id << 1)} "\
        '@text="8200" @fetched="true" @fullIdentifier="NISTIR8200:2018" '\
        '@title="8200">'
    end
  end

  it "return string of hit collection" do
    VCR.use_cassette "8200" do
      hits = NistBib::NistBibliography.search("8200", "2018").fetch
      expect(hits.to_s).to eq "<NistBib::HitCollection:"\
        "#{format('%#.14x', hits.object_id << 1)} "\
        "@fetched=true>"
    end
  end

  context "get" do
    it "a code" do
      VCR.use_cassette "8200" do
        result = NistBib::NistBibliography.get("8200", "2018", {}).to_xml bibdata: true
        file_path = "spec/examples/get.xml"
        File.write file_path, result unless File.exist? file_path
        expect(result).to be_equivalent_to File.
          open(file_path, "r:UTF-8", &:read).
          gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
      end
    end

    it "a reference with an year in a code" do
      VCR.use_cassette "8200_2017" do
        result = NistBib::NistBibliography.get("NISTIR 8200:2018").to_xml bibdata: true
        expect(result).to include "<on>2018-11</on>"
      end
    end

    it "DRAFT" do
      VCR.use_cassette "draft" do
        result = NistBib::NistBibliography.get("800-189", nil, {}).to_xml bibdata: true
        file_path = "spec/examples/draft.xml"
        File.write file_path, result unless File.exist? file_path
        expect(result).to be_equivalent_to File.open(file_path, "r:UTF-8", &:read)
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
      end
    end

    it "RETIRED DRAFT" do
      VCR.use_cassette "retired_draft" do
        result = NistBib::NistBibliography.get("7831", nil, {}).to_xml bibdata: true
        file_path = "spec/examples/retired_draft.xml"
        File.write file_path, result unless File.exist? file_path
        expect(result).to be_equivalent_to File.open(file_path, "r:UTF-8", &:read)
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
      end
    end

    it "doc with issued & published dates" do
      VCR.use_cassette "800_162" do
        result = NistBib::NistBibliography.get("SP 800-162", nil, {}).to_xml bibdata: true
        file_path = "spec/examples/issued_published_dates.xml"
        File.write file_path, result unless File.exist? file_path
        expect(result).to be_equivalent_to(
          File.open(file_path, "r:UTF-8", &:read).
            gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s),
        )
      end
    end

    it "FIPS doc with full issued date" do
      VCR.use_cassette "fips_140_3" do
        result = NistBib::NistBibliography.get("FIPS 140-3", nil, {}).to_xml bibdata: true
        file_path = "spec/examples/fips_140_3.xml"
        File.write file_path, result unless File.exist? file_path
        expect(result).to be_equivalent_to(
          File.open(file_path, "r:UTF-8", &:read).
            gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s),
        )
      end
    end
  end

  context "warns when" do
    it "a code matches a resource but the year does not" do
      VCR.use_cassette "8200_wrong_year" do
        expect { NistBib::NistBibliography.get("8200", "2017", {}) }.to output(
          "fetching 8200...\nWARNING: no match found online for 8200:2017. "\
          "The code must be exactly like it is on the standards website.\n",
        ).to_stderr
      end
    end

    it "search failed" do
      VCR.use_cassette "failed" do
        expect { NistBib::NistBibliography.get("2222", nil, {}) }.to output(
          "fetching 2222...\n"\
          "WARNING: no match found online for 2222. The code must be exactly "\
          "like it is on the standards website.\n",
        ).to_stderr
      end
    end
  end

  context "short citation" do
    context "without stage get" do
      it "undated reference" do
        VCR.use_cassette "undated_ref" do
          result = NistBib::NistBibliography.get("NIST SP 800-162")
          expect(result.id).to eq "SP800-162"
        end
      end

      it "final without updated-date" do
        VCR.use_cassette "final_without_updated_date" do
          result = NistBib::NistBibliography.get("SP 800-162 (January 2014)")
          expect(result.id).to eq "SP800-162"
        end
      end

      it "final where updated-date > original-release-date" do
        VCR.use_cassette "final_with_updated_date" do
          result = NistBib::NistBibliography.get "SP 800-162 (February 25, 2019)"
          expect(result.id).to eq "SP800-162"
        end
      end
    end

    context "with stage get" do
      it "draft without updated-date" do
        VCR.use_cassette "draft_without_updated_date" do
          result = NistBib::NistBibliography.get "SP 800-205 (February 2019) (PD)"
          expect(result.id).to eq "SP800-205(DRAFT)"
        end
      end

      it "draft with iitial iteration" do
        VCR.use_cassette "sp_800_57" do
          result = NistBib::NistBibliography.get("SP 800-57 (IPD)").to_xml
          file_path = "spec/examples/sp_800_57.xml"
          File.write file_path, result unless File.exist? file_path
          expect(result).to be_equivalent_to(
            File.open(file_path, "r:UTF-8", &:read).
              gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s),
          )
        end
      end

      it "draft with 2rd iteration" do
        VCR.use_cassette "sp_800_57_2iter" do
          result = NistBib::NistBibliography.get "SP 800-57 (2PD)"
          expect(result.title.first.title.content).to eq "Recommendation for Key Management, Part 2: Best Practices for Key Management Organizations (2nd Draft)"
        end
      end
    end
  end
end
