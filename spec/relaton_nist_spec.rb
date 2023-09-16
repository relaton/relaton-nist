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
    VCR.use_cassette "8200_2018" do
      hit_collection = RelatonNist::NistBibliography.search("NISTIR 8200", "2018")
      expect(hit_collection.fetched).to be false
      expect(hit_collection.fetch).to be_instance_of RelatonNist::HitCollection
      expect(hit_collection.fetched).to be true
      expect(hit_collection.first).to be_instance_of RelatonNist::Hit
    end
  end

  context "return xml of hit" do
    it "with bibdata root elemen" do
      VCR.use_cassette "8011_1" do
        hits = RelatonNist::NistBibliography.search("NISTIR 8011-1")
        file_path = "spec/examples/hit.xml"
        xml = hits.first.to_xml(bibdata: true)
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        File.write file_path, xml, encoding: "UTF-8" unless File.exist? file_path
        expect(xml).to be_equivalent_to File.open(file_path, "r:UTF-8", &:read)
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        schema = Jing.new "grammars/relaton-nist-compile.rng"
        errors = schema.validate file_path
        expect(errors).to eq []
      end
    end

    it "with bibitem root elemen" do
      VCR.use_cassette "8011_1" do
        hits = RelatonNist::NistBibliography.search("NISTIR 8011-1")
        file_path = "spec/examples/hit_bibitem.xml"
        xml = hits.first.to_xml
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        File.write file_path, xml, encoding: "UTF-8" unless File.exist? file_path
        expect(xml).to be_equivalent_to File.open(file_path, "r:UTF-8", &:read)
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
      end
    end
  end

  it "return AsciiBib" do
    hash = YAML.load_file "spec/examples/nist_bib_item.yml"
    item_hash = RelatonNist::HashConverter.hash_to_bib hash
    item = RelatonNist::NistBibliographicItem.new(**item_hash)
    bib = item.to_asciibib
      .gsub(/(?<=fetched::\s)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
    file = "spec/examples/asciibib.adoc"
    File.write file, bib, encoding: "UTF-8" unless File.exist? file
    expect(bib).to eq File.read(file, encoding: "UTF-8")
      .gsub(/(?<=fetched::\s)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
  end

  it "return string of hit" do
    VCR.use_cassette "8200_2018" do
      hits = RelatonNist::NistBibliography.search("NISTIR 8200", "2018").fetch
      expect(hits.first.to_s).to eq(
        "<RelatonNist::Hit:" \
        "#{format('%<id>#.14x', id: hits.first.object_id << 1)} " \
        '@text="NIST IR 8200" @fetched="true" ' \
        '@fullIdentifier="NISTIR8200:2018" @title="NIST IR 8200">',
      )
    end
  end

  it "return string of hit collection" do
    VCR.use_cassette "8200_2018" do
      hits = RelatonNist::NistBibliography.search("NISTIR 8200", "2018").fetch
      expect(hits.to_s).to eq(
        "<RelatonNist::HitCollection:" \
        "#{format('%<id>#.14x', id: hits.object_id << 1)} " \
        "@ref=NIST IR 8200 @fetched=true>",
      )
    end
  end

  context "get" do
    it "a code" do
      VCR.use_cassette "8200_2018" do
        result = RelatonNist::NistBibliography.get("NISTIR 8200", "2018", {})
        xml = result.to_xml(bibdata: true)
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        file_path = "spec/examples/get.xml"
        File.write file_path, xml, encoding: "UTF-8" unless File.exist? file_path
        expect(xml).to be_equivalent_to File.open(file_path, "r:UTF-8", &:read)
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        schema = Jing.new "grammars/relaton-nist-compile.rng"
        errors = schema.validate file_path
        expect(errors).to eq []
      end
    end

    it "document" do
      VCR.use_cassette "8200" do
        item = RelatonNist::NistBibliography.get "NISTIR 8200", "2018"
        expect(item.docidentifier.first.id).to eq "NIST IR 8200"
      end
    end

    it "a reference with an year in a code" do
      VCR.use_cassette "8200_2018" do
        result = RelatonNist::NistBibliography.get("NISTIR 8200-2018")
          .to_xml bibdata: true
        expect(result).to include "<on>2018-11</on>"
      end
    end

    it "a code with an year from json", vcr: { cassette_name: "json_data" } do
      result = RelatonNist::NistBibliography.get "FIPS 140-2", "2001"
      expect(result.docidentifier.first.id).to eq "NIST FIPS 140-2r2 fpd"
      expect(result.date.find { |d| d.type == "published" }.on).to eq "2001-05-25"
    end

    it "DRAFT", vcr: { cassette_name: "json_data" } do
      result = RelatonNist::NistBibliography.get("NIST SP 800-189 2PD", nil, {})
        .to_xml bibdata: true
      file_path = "spec/examples/draft.xml"
      File.write file_path, result, encoding: "UTF-8" unless File.exist? file_path
      expect(result).to be_equivalent_to File.open(
        file_path, "r:UTF-8", &:read
      ).gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
      schema = Jing.new "grammars/relaton-nist-compile.rng"
      errors = schema.validate file_path
      expect(errors).to eq []
    end

    # it "RETIRED DRAFT" do
    #   VCR.use_cassette "json_data" do
    #     result = RelatonNist::NistBibliography.get("SP 800-80(PD)", nil, {}).to_xml bibdata: true
    #     file_path = "spec/examples/retired_draft.xml"
    #     File.write file_path, result, encoding: "UTF-8" unless File.exist? file_path
    #     expect(result).to be_equivalent_to File.open(
    #       file_path, "r:UTF-8", &:read
    #     ).gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
    #     schema = Jing.new "grammars/relaton-nist-compile.rng"
    #     errors = schema.validate file_path
    #     expect(errors).to eq []
    #   end
    # end

    # it "DRAFT OBSOLETE" do
    #   VCR.use_cassette "draft_obsolete" do
    #     result = RelatonNist::NistBibliography.get("SP 800-189(PD)", nil, {})
    #       .to_xml bibdata: true
    #     file_path = "spec/examples/draft_obsolete.xml"
    #     File.write file_path, result, encoding: "UTF-8" unless File.exist? file_path
    #     expect(result).to be_equivalent_to File.open(file_path, "r:UTF-8", &:read)
    #       .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
    #     schema = Jing.new "grammars/relaton-nist-compile.rng"
    #     errors = schema.validate file_path
    #     expect(errors).to eq []
    #   end
    # end

    # it "doc with issued & published dates" do
    #   VCR.use_cassette "json_data" do
    #     result = RelatonNist::NistBibliography.get("SP 800-162", nil, {})
    #       .to_xml bibdata: true
    #     file_path = "spec/examples/issued_published_dates.xml"
    #     File.write file_path, result, encoding: "UTF-8" unless File.exist? file_path
    #     expect(result).to be_equivalent_to(
    #       File.open(file_path, "r:UTF-8", &:read)
    #         .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s),
    #     )
    #     schema = Jing.new "grammars/relaton-nist-compile.rng"
    #     errors = schema.validate file_path
    #     expect(errors).to eq []
    #   end
    # end

    # it "FIPS doc with full issued date" do
    #   VCR.use_cassette "json_data" do
    #     result = RelatonNist::NistBibliography.get("FIPS 140-3", nil, {})
    #       .to_xml bibdata: true
    #     file_path = "spec/examples/fips_140_3.xml"
    #     File.write file_path, result, encoding: "UTF-8" unless File.exist? file_path
    #     expect(result).to be_equivalent_to(
    #       File.open(file_path, "r:UTF-8", &:read)
    #         .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s),
    #     )
    #     schema = Jing.new "grammars/relaton-nist-compile.rng"
    #     errors = schema.validate file_path
    #     expect(errors).to eq []
    #   end
    # end

    # it "NIST CMVP", vcr: { cassette_name: "nist_cmvp" } do
    #   item = RelatonNist::NistBibliography.get("NIST CMVP", nil, {})
    #   expect(item).to be_nil
    # end

    it "should not resolve NIST SP 800-53 RES" do
      item = RelatonNist::NistBibliography.get("NIST SP 800-53 RES", nil, {})
      expect(item).to be_nil
    end

    # it "doc with edition" do
    #   VCR.use_cassette "json_data" do
    #     result = RelatonNist::NistBibliography.get "FIPS 140-2"
    #     expect(result.edition.content).to eq "Revision 2"
    #   end
    # end

    context "doc with specific revision" do
      it "1 short notation", vcr: { cassette_name: "nist_sp_800_67r1" } do
        bib = RelatonNist::NistBibliography.get "NIST SP 800-67r1"
        expect(bib.docidentifier[0].id).to eq "NIST SP 800-67r1 fpd"
      end

      it "2 short notation", vcr: { cassette_name: "nist_sp_800_67r2" } do
        bib = RelatonNist::NistBibliography.get "NIST SP 800-67r2"
        expect(bib.docidentifier[0].id).to eq "NIST SP 800-67r2 fpd"
      end

      # it "1 long notation", vcr: { cassette_name: "nist_sp_800_67r1" } do
      #   bib = RelatonNist::NistBibliography.get "NIST SP 800-67 Rev. 1"
      #   expect(bib.docidentifier[0].id).to eq "NIST SP 800-67 Rev. 1"
      # end

      # it "2 long notation", vcr: { cassette_name: "nist_sp_800_67r2" } do
      #   bib = RelatonNist::NistBibliography.get "NIST SP 800-67 Rev. 2"
      #   expect(bib.docidentifier[0].id).to eq "NIST SP 800-67 Rev. 2"
      # end
    end

    context "doc with specific version" do
      it "short notation", vcr: { cassette_name: "nist_sp_800_45ver2" } do
        bib = RelatonNist::NistBibliography.get "NIST SP 800-45ver2"
        expect(bib.docidentifier[0].id).to eq "NIST SP 800-45ver2 fpd"
      end

      it "long notation", vcr: { cassette_name: "nist_sp_800_45ver2" } do
        bib = RelatonNist::NistBibliography.get "NIST SP 800-45 Ver. 2"
        expect(bib.docidentifier[0].id).to eq "NIST SP 800-45ver2 fpd"
      end
    end

    context "doc with specific part & revision" do
      it "short notation", vcr: { cassette_name: "nist_sp_800_57pt1r4" } do
        bib = RelatonNist::NistBibliography.get "NIST SP 800-57pt1r4"
        expect(bib.docidentifier[0].id).to eq "NIST SP 800-57pt1r4 fpd"
      end

      # it "long notation", vcr: { cassette_name: "nist_sp_800_57pt1r4" } do
      #   bib = RelatonNist::NistBibliography.get "NIST SP 800-57 Part 1 Rev. 4"
      #   expect(bib.docidentifier[0].id).to eq "NIST SP 800-57 Part 1 Rev. 4"
      # end
    end

    context "doc with specific volume" do
      it "short notation" do
        VCR.use_cassette "nistir_5667v4" do
          bib = RelatonNist::NistBibliography.get "NISTIR 5667v4"
          expect(bib.docidentifier[0].id).to eq "NIST IR 5667v4"
        end
      end

      # it "long notation" do
      #   VCR.use_cassette "nistir_5667v4" do
      #     bib = RelatonNist::NistBibliography.get "NISTIR 5667 Vol. 4"
      #     expect(bib.docidentifier[0].id).to eq "NIST IR 5667v4"
      #   end
      # end
    end

    context "doc using MR identifiers" do
      it "with volume and revision", vcr: { cassette_name: "nist_sp_800_60v1r1" } do
        bib = RelatonNist::NistBibliography.get "NIST.SP.800-60v1r1"
        expect(bib.docidentifier[0].id).to eq "NIST SP 800-60v1r1 fpd"
      end

      # it "with version" do
      #   VCR.use_cassette "json_data" do
      #     bib = RelatonNist::NistBibliography.get "NIST.SP.800-63.ver1-0-2.eng"
      #     expect(bib.docidentifier[0].id).to eq "SP 800-63 Ver. 1.0.2"
      #   end
      # end

      it "with part and revision", vcr: { cassette_name: "nist_sp_800_57pt1r4" } do
        bib = RelatonNist::NistBibliography.get "NIST.SP.800-57pt1r4"
        expect(bib.docidentifier[0].id).to eq "NIST SP 800-57pt1r4 fpd"
      end

      it "public draft", vcr: { cassette_name: "nist_sp_800_66r1_ipd" } do
        bib = RelatonNist::NistBibliography.get "NIST SP 800-66r2 ipd"
        expect(bib.docidentifier[0].id).to eq "NIST SP 800-66r2 ipd"
      end
    end

    # it "doc with supersedes" do
    #   VCR.use_cassette "nist_fips_140_2" do
    #     result = RelatonNist::NistBibliography.get "NIST FIPS 140-2"
    #     expect(result.relation.first).to be_instance_of(
    #       RelatonNist::DocumentRelation,
    #     )
    #     expect(result.relation.first.type).to eq "obsoletes"
    #     expect(result.relation.first.description.content).to eq "supersedes"
    #   end
    # end

    # it "draft active" do
    #   VCR.use_cassette "nist_sp_800_140_pd" do
    #     result = RelatonNist::NistBibliography.get "NIST SP 800-140 (PD)"
    #     expect(result.status.stage.value).to eq "draft-public"
    #     expect(result.status.substage.value).to eq "withdrawn"
    #   end
    # end

    # it "doc with White Paper as id" do
    #   VCR.use_cassette "framework" do
    #     result = RelatonNist::NistBibliography.get(
    #       "NIST Framework for "\
    #       "Improving Critical Infrastructure Cybersecurity, Version 1.1",
    #     ).to_xml bibdata: true
    #     file_path = "spec/examples/framework.xml"
    #     File.write file_path, result unless File.exist? file_path
    #     expect(result).to be_equivalent_to(
    #       File.open(file_path, "r:UTF-8", &:read)
    #         .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s),
    #     )
    #     schema = Jing.new "grammars/relaton-nist-compile.rng"
    #     errors = schema.validate file_path
    #     expect(errors).to eq []
    #   end
    # end

    it "get NIST SP 800-12" do
      VCR.use_cassette "nist_sp_800_12" do
        result = RelatonNist::NistBibliography.get "NIST SP 800-12"
        expect(result.docidentifier.first.id).to eq "NIST SP 800-12 fpd"
      end
    end

    # it "get NIST SP 800-55 Rev. 1" do
    #   VCR.use_cassette "nist_sp_800_55_rev_1" do
    #     result = RelatonNist::NistBibliography.get "NIST SP 800-55 Rev. 1"
    #     expect(result.contributor.last.entity.affiliation).to be_none
    #   end
    # end

    it "get NIST IR 7916" do
      VCR.use_cassette "nist_ir_7916" do
        result = RelatonNist::NistBibliography.get "NIST IR 7916"
        expect(result.docidentifier.first.id).to eq "NIST IR 7916"
      end
    end

    it "get NIST SP 500-183" do
      VCR.use_cassette "nist_sp_500_183" do
        result = RelatonNist::NistBibliography.get "NIST SP 500-183"
        expect(result.docidentifier.first.id).to eq "NIST SP 500-183"
      end
    end

    # it "draft without (PD) in reference return nil" do
    #   VCR.use_cassette "sp_800_90c" do
    #     result = RelatonNist::NistBibliography.get "SP 800-90C"
    #     expect(result).to be_nil
    #   end
    # end

    it "Addendum" do
      VCR.use_cassette "json_data" do
        bib = RelatonNist::NistBibliography.get "NIST SP 800-38a-add"
        expect(bib.docidentifier[0].id).to eq "NIST SP 800-38A fpd Add."
      end
    end

    it "not Addendum" do
      VCR.use_cassette "sp_800_38a" do
        bib = RelatonNist::NistBibliography.get "NIST SP 800-38a"
        expect(bib.docidentifier[0].id).to eq "NIST SP 800-38A fpd"
      end
    end

    it "get incomplete reference", vcr: { cassette_name: "nist_sp_800_60v1" } do
      bib = RelatonNist::NistBibliography.get "NIST SP 800-60v1"
      expect(bib.docidentifier[0].id).to eq "NIST SP 800-60v1r1 fpd"
    end

    # it "get CSWP", vcr: { cassette_name: "nist_cswp" } do
    #   bib = RelatonNist::NistBibliography.get "NIST CSWP 16 (IPD)"
    #   xml = bib.to_xml bibdata: true
    #   file = "spec/examples/cswp.xml"
    #   File.write file, xml, encoding: "UTF-8" unless File.exist? file
    #   expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
    #     .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
    # end
  end

  context "warns when" do
    it "a code matches a resource but the year does not" do
      VCR.use_cassette "8200_wrong_year" do
        expect do
          RelatonNist::NistBibliography.get("NISTIR 8200", "2017", {})
        end.to output(
          /\[relaton-nist\] WARNING: no match found online for NISTIR 8200:2017/,
        ).to_stderr
      end
    end

    it "search failed" do
      expect do
        RelatonNist::NistBibliography.get("NIST SP 2222", nil, {})
      end.to output(
        /\[relaton-nist\] WARNING: no match found online for NIST SP 2222/,
      ).to_stderr
    end

    # it "contains EP at the end" do
    #   expect { RelatonNist::NistBibliography.get "NIST FIPS 201 EP" }.to output(
    #     /WARNING: no match found online for NIST FIPS 201 EP/,
    #   ).to_stderr
    # end
  end

  context "short citation" do
    context "without stage get" do
      it "undated reference", vcr: { cassette_name: "nist_sp_800_162" } do
        result = RelatonNist::NistBibliography.get("NIST SP 800-162")
        expect(result.id).to eq "NISTSP800-162fpd"
      end

      # it "final without updated-date", vcr: { cassette_name: "nist_sp_800_162_2014_01" } do
      #   result = RelatonNist::NistBibliography.get "NIST SP 800-162 (January 2014)"
      #   expect(result.id).to eq "NISTSP800-162"
      # end

      # it "final where updated-date > original-release-date" do
      #   VCR.use_cassette "json_data" do
      #     result = RelatonNist::NistBibliography.get(
      #       "SP 800-162 (February 25, 2019)",
      #     )
      #     expect(result.id).to eq "SP800-162"
      #   end
      # end
    end

    context "with stage get" do
      # it "draft without updated-date" do
      #   VCR.use_cassette "json_data" do
      #     result = RelatonNist::NistBibliography.get(
      #       "SP 800-205 (February 2019) (PD)",
      #     )
      #     expect(result.id).to eq "SP800-205(Draft)"
      #   end
      # end

      # it "draft with initial iteration", vcr: { cassette_name: "nist_sp_800_37r2" } do
      #   result = RelatonNist::NistBibliography.get("NIST SP 800-37r2 (IPD)").to_xml
      #   file_path = "spec/examples/sp_800_57.xml"
      #   File.write file_path, result, encoding: "UTF-8" unless File.exist? file_path
      #   expect(result).to be_equivalent_to(
      #     File.open(file_path, "r:UTF-8", &:read)
      #       .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s),
      #   )
      # end

      # it "draft with 2rd iteration", vcr: { cassette_name: "nist_sp_57pt2r1" } do
      #   result = RelatonNist::NistBibliography.get "SP 800-57pt2r1 (2PD)"
      #   expect(result.title.first.title.content).to eq(
      #     "Recommendation for Key Management - Part 2: Best Practices for "\
      #     "Key Management Organizations",
      #   )
      #   expect(result.status.iteration).to eq "2"
      # end

      # it "final draft", vcr: { cassette_name: "nist_sp_800_37r2" } do
      #   result = RelatonNist::NistBibliography.get "SP 800-37r2 (FPD)"
      #   expect(result.title.first.title.content).to eq(
      #     "Risk Management Framework for Information Systems and "\
      #     "Organizations - A System Life Cycle Approach for Security and "\
      #     "Privacy",
      #   )
      #   expect(result.status.iteration).to eq "final"
      # end
    end
  end
end
