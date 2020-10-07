require "jing"

RSpec.describe RelatonNist do
  it "has a version number" do
    expect(RelatonNist::VERSION).not_to be nil
  end

  it "returs grammar hash" do
    hash = RelatonNist.grammar_hash
    expect(hash).to be_instance_of String
    expect(hash.size).to eq 32
  end

  it "fetch hit" do
    VCR.use_cassette "8200" do
      hit_collection = RelatonNist::NistBibliography
        .search("NISTIR 8200", "2018")
      expect(hit_collection.fetched).to be false
      expect(hit_collection.fetch).to be_instance_of RelatonNist::HitCollection
      expect(hit_collection.fetched).to be true
      expect(hit_collection.first).to be_instance_of RelatonNist::Hit
    end
  end

  context "return xml of hit" do
    it "with bibdata root elemen" do
      VCR.use_cassette "8011" do
        hits = RelatonNist::NistBibliography.search("NISTIR 8011")
        file_path = "spec/examples/hit.xml"
        xml = hits.first.to_xml bibdata: true
        File.write file_path, xml unless File.exist? file_path
        expect(xml).to be_equivalent_to File.open(file_path, "r:UTF-8", &:read)
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        schema = Jing.new "spec/examples/isobib.rng"
        errors = schema.validate file_path
        expect(errors).to eq []
      end
    end

    it "with bibitem root elemen" do
      VCR.use_cassette "8011" do
        hits = RelatonNist::NistBibliography.search("NISTIR 8011")
        file_path = "spec/examples/hit_bibitem.xml"
        File.write file_path, hits.first.to_xml unless File.exist? file_path
        expect(hits.first.to_xml).to be_equivalent_to File
          .open(file_path, "r:UTF-8", &:read)
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
      end
    end
  end

  it "return AsciiBib" do
    hash = YAML.load_file "spec/examples/nist_bib_item.yml"
    item_hash = RelatonNist::HashConverter.hash_to_bib hash
    item = RelatonNist::NistBibliographicItem.new item_hash
    bib = item.to_asciibib
    file = "spec/examples/asciibib.adoc"
    File.write file, bib, encoding: "UTF-8" unless File.exist? file
    expect(bib).to eq File.read(file, encoding: "UTF-8")
      .gsub(/(?<=fetched::\s)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
  end

  it "return string of hit" do
    VCR.use_cassette "8200" do
      hits = RelatonNist::NistBibliography.search("NISTIR 8200", "2018").fetch
      expect(hits.first.to_s).to eq "<RelatonNist::Hit:"\
        "#{format('%<id>#.14x', id: hits.first.object_id << 1)} "\
        '@text="NISTIR 8200" @fetched="true" '\
        '@fullIdentifier="NISTIR8200:2018" '\
        '@title="8200">'
    end
  end

  it "return string of hit collection" do
    VCR.use_cassette "8200" do
      hits = RelatonNist::NistBibliography.search("NISTIR 8200", "2018").fetch
      expect(hits.to_s).to eq "<RelatonNist::HitCollection:"\
        "#{format('%<id>#.14x', id: hits.object_id << 1)} "\
        "@ref=NISTIR 8200 @fetched=true>"
    end
  end

  context "get" do
    it "a code" do
      VCR.use_cassette "8200" do
        result = RelatonNist::NistBibliography.get("NISTIR 8200", "2018", {})
          .to_xml bibdata: true
        file_path = "spec/examples/get.xml"
        File.write file_path, result unless File.exist? file_path
        expect(result).to be_equivalent_to File.open(
          file_path, "r:UTF-8", &:read
        ).gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        schema = Jing.new "spec/examples/isobib.rng"
        errors = schema.validate file_path
        expect(errors).to eq []
      end
    end

    it "a reference with an year in a code" do
      VCR.use_cassette "8200_2017" do
        result = RelatonNist::NistBibliography.get("NISTIR 8200:2018")
          .to_xml bibdata: true
        expect(result).to include "<on>2018-11</on>"
      end
    end

    it "a code with an year form json" do
      VCR.use_cassette "json_data" do
        result = RelatonNist::NistBibliography.get "SP 500-304", "2015"
        expect(result.id).to eq "SP500-304"
      end
    end

    it "DRAFT" do
      VCR.use_cassette "json_data" do
        result = RelatonNist::NistBibliography.get("SP 800-189(PD)", nil, {})
          .to_xml bibdata: true
        file_path = "spec/examples/draft.xml"
        File.write file_path, result unless File.exist? file_path
        expect(result).to be_equivalent_to File.open(
          file_path, "r:UTF-8", &:read
        ).gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        schema = Jing.new "spec/examples/isobib.rng"
        errors = schema.validate file_path
        expect(errors).to eq []
      end
    end

    it "RETIRED DRAFT" do
      VCR.use_cassette "retired_draft" do
        result = RelatonNist::NistBibliography.get("NISTIR 7831(PD)", nil, {})
          .to_xml bibdata: true
        file_path = "spec/examples/retired_draft.xml"
        File.write file_path, result unless File.exist? file_path
        expect(result).to be_equivalent_to File.open(
          file_path, "r:UTF-8", &:read
        ).gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        schema = Jing.new "spec/examples/isobib.rng"
        errors = schema.validate file_path
        expect(errors).to eq []
      end
    end

    it "DRAFT OBSOLETE" do
      VCR.use_cassette "draft_obsolete" do
        result = RelatonNist::NistBibliography.get("SP 800-189(PD)", nil, {})
          .to_xml bibdata: true
        file_path = "spec/examples/draft_obsolete.xml"
        File.write file_path, result unless File.exist? file_path
        expect(result).to be_equivalent_to File.open(
          file_path, "r:UTF-8", &:read
        ).gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        schema = Jing.new "spec/examples/isobib.rng"
        errors = schema.validate file_path
        expect(errors).to eq []
      end
    end

    it "doc with issued & published dates" do
      VCR.use_cassette "json_data" do
        result = RelatonNist::NistBibliography.get("SP 800-162", nil, {})
          .to_xml bibdata: true
        file_path = "spec/examples/issued_published_dates.xml"
        File.write file_path, result unless File.exist? file_path
        expect(result).to be_equivalent_to(
          File.open(file_path, "r:UTF-8", &:read)
            .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        )
        schema = Jing.new "spec/examples/isobib.rng"
        errors = schema.validate file_path
        expect(errors).to eq []
      end
    end

    it "FIPS doc with full issued date" do
      VCR.use_cassette "json_data" do
        result = RelatonNist::NistBibliography.get("FIPS 140-3", nil, {})
          .to_xml bibdata: true
        file_path = "spec/examples/fips_140_3.xml"
        File.write file_path, result unless File.exist? file_path
        expect(result).to be_equivalent_to(
          File.open(file_path, "r:UTF-8", &:read)
            .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        )
        schema = Jing.new "spec/examples/isobib.rng"
        errors = schema.validate file_path
        expect(errors).to eq []
      end
    end

    it "doc with edition" do
      VCR.use_cassette "json_data" do
        result = RelatonNist::NistBibliography.get "FIPS 140-2"
        expect(result.edition).to eq "Revision 2"
      end
    end

    it "doc with supersedes" do
      VCR.use_cassette "nistir_8204" do
        result = RelatonNist::NistBibliography.get "NISTIR 8204"
        expect(result.relation.first).to be_instance_of(
          RelatonNist::DocumentRelation
        )
      end
    end

    it "draft active" do
      VCR.use_cassette "nistir_8259_pd" do
        result = RelatonNist::NistBibliography.get "NISTIR 8259 (PD)"
        expect(result.status.stage.value).to eq "draft-public"
        expect(result.status.substage.value).to eq "active"
      end
    end

    it "doc with White Paper as id" do
      VCR.use_cassette "framework" do
        result = RelatonNist::NistBibliography.get("NIST Framework for "\
          "Improving Critical Infrastructure Cybersecurity Version 1.1")
          .to_xml bibdata: true
        file_path = "spec/examples/framework.xml"
        File.write file_path, result unless File.exist? file_path
        expect(result).to be_equivalent_to(
          File.open(file_path, "r:UTF-8", &:read)
            .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        )
        schema = Jing.new "spec/examples/isobib.rng"
        errors = schema.validate file_path
        expect(errors).to eq []
      end
    end

    it "get NIST SP 800-12" do
      VCR.use_cassette "nist_sp_800_12" do
        result = RelatonNist::NistBibliography.get "NIST SP 800-12"
        expect(result.docidentifier.first.id).to eq "SP 800-12"
      end
    end

    it "get NIST SP 800-55 Rev. 1" do
      VCR.use_cassette "nist_sp_800_55_rev_1" do
        result = RelatonNist::NistBibliography.get "NIST SP 800-55 Rev. 1"
        expect(result.contributor.last.entity.affiliation).to be_none
      end
    end

    it "draft without (PD) in reference return nil" do
      VCR.use_cassette "sp_800_90c" do
        result = RelatonNist::NistBibliography.get "SP 800-90C"
        expect(result).to be_nil
      end
    end
  end

  context "warns when" do
    it "a code matches a resource but the year does not" do
      VCR.use_cassette "8200_wrong_year" do
        expect do
          RelatonNist::NistBibliography.get("NISTIR 8200", "2017", {})
        end.to output(
          /\[relaton-nist\] WARNING: no match found online for NISTIR 8200:2017/
        ).to_stderr
      end
    end

    it "search failed" do
      VCR.use_cassette "json_data" do
        expect do
          RelatonNist::NistBibliography.get("SP 2222", nil, {})
        end.to output(
          /\[relaton-nist\] WARNING: no match found online for SP 2222/
        ).to_stderr
      end
    end

    it "contains EP at the end" do
      expect { RelatonNist::NistBibliography.get "FIPS 201 EP" }.to output(
        /WARNING: no match found online for FIPS 201 EP/
      ).to_stderr
    end
  end

  context "short citation" do
    context "without stage get" do
      it "undated reference" do
        VCR.use_cassette "json_data" do
          result = RelatonNist::NistBibliography.get("NIST SP 800-162")
          expect(result.id).to eq "SP800-162"
        end
      end

      it "final without updated-date" do
        VCR.use_cassette "json_data" do
          result = RelatonNist::NistBibliography.get "SP 800-162 (January 2014)"
          expect(result.id).to eq "SP800-162"
        end
      end

      it "final where updated-date > original-release-date" do
        VCR.use_cassette "json_data" do
          result = RelatonNist::NistBibliography.get(
            "SP 800-162 (February 25, 2019)"
          )
          expect(result.id).to eq "SP800-162"
        end
      end
    end

    context "with stage get" do
      it "draft without updated-date" do
        VCR.use_cassette "json_data" do
          result = RelatonNist::NistBibliography.get(
            "SP 800-205 (February 2019) (PD)"
          )
          expect(result.id).to eq "SP800-205(Draft)"
        end
      end

      it "draft with initial iteration" do
        VCR.use_cassette "json_data" do
          result = RelatonNist::NistBibliography.get("SP 800-37 (IPD)").to_xml
          file_path = "spec/examples/sp_800_57.xml"
          File.write file_path, result unless File.exist? file_path
          expect(result).to be_equivalent_to(
            File.open(file_path, "r:UTF-8", &:read)
              .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
          )
        end
      end

      it "draft with 2rd iteration" do
        VCR.use_cassette "json_data" do
          result = RelatonNist::NistBibliography.get "SP 800-57 (2PD)"
          expect(result.title.first.title.content).to eq(
            "Recommendation for Key Management - Part 2: Best Practices for "\
            "Key Management Organizations"
          )
          expect(result.status.iteration).to eq "2"
        end
      end

      it "final draft" do
        VCR.use_cassette "json_data" do
          result = RelatonNist::NistBibliography.get "SP 800-37 (FPD)"
          expect(result.title.first.title.content).to eq("Risk Management "\
            "Framework for Information Systems and Organizations - A System "\
            "Life Cycle Approach for Security and Privacy")
          expect(result.status.iteration).to eq "final"
        end
      end
    end
  end
end
