require "jing"

RSpec.describe Relaton::Nist do
  it "has a version number" do
    expect(Relaton::Nist::VERSION).not_to be nil
  end

  it "returs grammar hash" do
    hash = Relaton::Nist.grammar_hash
    expect(hash).to be_instance_of String
    expect(hash.size).to eq 32
  end

  context "fetch from GH" do
    before do
      # Force to download index file
      allow_any_instance_of(Relaton::Index::Type).to receive(:actual?).and_return(false)
      allow_any_instance_of(Relaton::Index::FileIO).to receive(:check_file).and_return(nil)
    end

    it "fetch hit", vcr: "8200_2018" do
      hit_collection = Relaton::Nist::Bibliography.search("NIST IR 8200", "2018")
      expect(hit_collection.fetched).to be false
      expect(hit_collection.fetch).to be_instance_of Relaton::Nist::HitCollection
      expect(hit_collection.fetched).to be true
      expect(hit_collection.first).to be_instance_of Relaton::Nist::Hit
    end

    context "return xml of hit", vcr: "8011_1" do
      it "with bibdata root elemen" do
        hits = Relaton::Nist::Bibliography.search("NISTIR 8011-1")
        file_path = "spec/fixtures/hit.xml"
        xml = hits.first.item.to_xml(bibdata: true)
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, ::Date.today.to_s)
        File.write file_path, xml, encoding: "UTF-8" unless File.exist? file_path
        expect(xml).to be_equivalent_to File.open(file_path, "r:UTF-8", &:read)
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, ::Date.today.to_s)
        schema = Jing.new "grammars/relaton-nist-compile.rng"
        errors = schema.validate file_path
        expect(errors).to eq []
      end

      it "with bibitem root elemen" do
        hits = Relaton::Nist::Bibliography.search("NISTIR 8011-1")
        file_path = "spec/fixtures/hit_bibitem.xml"
        xml = hits.first.item.to_xml
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, ::Date.today.to_s)
        File.write file_path, xml, encoding: "UTF-8" unless File.exist? file_path
        expect(xml).to be_equivalent_to File.open(file_path, "r:UTF-8", &:read)
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, ::Date.today.to_s)
      end
    end

    it "return string of hit" do
      VCR.use_cassette "8200_2018" do
        hits = Relaton::Nist::Bibliography.search("NISTIR 8200", "2018").fetch
        expect(hits.first.to_s).to eq(
          "<Relaton::Nist::Hit:" \
          "#{format('%<id>#.14x', id: hits.first.object_id << 1)} " \
          "@reference=\"NIST IR 8200\" @fetched=\"true\" " \
          "@docidentifier=\"NIST IR 8200\">",
        )
      end
    end

    it "return string of hit collection" do
      VCR.use_cassette "8200_2018" do
        hits = Relaton::Nist::Bibliography.search("NISTIR 8200", "2018").fetch
        expect(hits.to_s).to eq(
          "<Relaton::Nist::HitCollection:" \
          "#{format('%<id>#.14x', id: hits.object_id << 1)} " \
          "@ref=NIST IR 8200 @fetched=true>",
        )
      end
    end

    context "get" do
      it "a code" do
        VCR.use_cassette "8200_2018" do
          result = Relaton::Nist::Bibliography.get("NISTIR 8200", "2018", {})
          xml = result.to_xml(bibdata: true).gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, ::Date.today.to_s)
          file_path = "spec/fixtures/get.xml"
          File.write file_path, xml, encoding: "UTF-8" unless File.exist? file_path
          expect(xml).to be_equivalent_to File.open(file_path, "r:UTF-8", &:read)
            .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, ::Date.today.to_s)
          schema = Jing.new "grammars/relaton-nist-compile.rng"
          errors = schema.validate file_path
          expect(errors).to eq []
        end
      end

      it "document", vcr: "8200" do
        expect do
          item = Relaton::Nist::Bibliography.get "NISTIR 8200", "2018"
          expect(item.docidentifier.first.content).to eq "NIST IR 8200"
        end.to output(
          match(/\[relaton-nist\] INFO: \(NIST IR 8200\) Fetching from Relaton repository \.\.\./)
            .and(match(/\[relaton-nist\] INFO: \(NIST IR 8200\) Found: `NIST IR 8200`/)),
        ).to_stderr_from_any_process
      end

      it "a reference with an year in a code" do
        VCR.use_cassette "8200_2018" do
          result = Relaton::Nist::Bibliography.get("NISTIR 8200:2018")
            .to_xml bibdata: true
          expect(result).to include "<on>2018</on>"
        end
      end

      it "NIST SP 800-53 RES", vcr: { cassette_name: "nist_sp_800_53_res" } do
        expect(Relaton::Nist::Bibliography.get("NIST SP 800-53 RES")).to be_nil
      end

      context "doc with specific revision" do
        it "1 short notation", vcr: { cassette_name: "nist_sp_800_67r1" } do
          bib = Relaton::Nist::Bibliography.get "NIST SP 800-67r1"
          expect(bib.docidentifier[0].content).to eq "NIST SP 800-67r1 fpd"
        end

        it "2 short notation", vcr: { cassette_name: "nist_sp_800_67r2" } do
          bib = Relaton::Nist::Bibliography.get "NIST SP 800-67r2"
          expect(bib.docidentifier[0].content).to eq "NIST SP 800-67r2 fpd"
        end

        it "1 long notation", vcr: { cassette_name: "nist_sp_800_67r1" } do
          bib = Relaton::Nist::Bibliography.get "NIST SP 800-67 Rev. 1"
          expect(bib.docidentifier[0].content).to eq "NIST SP 800-67r1 fpd"
        end

        it "2 long notation", vcr: { cassette_name: "nist_sp_800_67r2" } do
          bib = Relaton::Nist::Bibliography.get "NIST SP 800-67 Rev. 2"
          expect(bib.docidentifier[0].content).to eq "NIST SP 800-67r2 fpd"
        end
      end

      context "doc with specific version" do
        it "short notation", vcr: { cassette_name: "nist_sp_800_45ver2" } do
          bib = Relaton::Nist::Bibliography.get "NIST SP 800-45ver2"
          expect(bib.docidentifier[0].content).to eq "NIST SP 800-45ver2 fpd"
        end

        it "long notation", vcr: { cassette_name: "nist_sp_800_45ver2" } do
          bib = Relaton::Nist::Bibliography.get "NIST SP 800-45 Ver. 2"
          expect(bib.docidentifier[0].content).to eq "NIST SP 800-45ver2 fpd"
        end
      end

      context "doc with specific part & revision" do
        it "short notation", vcr: { cassette_name: "nist_sp_800_57pt1r4" } do
          bib = Relaton::Nist::Bibliography.get "NIST SP 800-57pt1r4"
          expect(bib.docidentifier[0].content).to eq "NIST SP 800-57pt1r4 fpd"
        end

        it "long notation", vcr: { cassette_name: "nist_sp_800_57pt1r4" } do
          bib = Relaton::Nist::Bibliography.get "NIST SP 800-57 Part 1 Rev. 4"
          expect(bib.docidentifier[0].content).to eq "NIST SP 800-57pt1r4 fpd"
        end
      end

      context "doc with specific volume", vcr: "nistir_5667v4" do
        it "short notation" do
          bib = Relaton::Nist::Bibliography.get "NISTIR 5667v4"
          expect(bib.docidentifier[0].content).to eq "NIST IR 5667v4"
        end
      end

      it "get NIST SP 800-12" do
        VCR.use_cassette "nist_sp_800_12" do
          result = Relaton::Nist::Bibliography.get "NIST SP 800-12"
          expect(result.docidentifier.first.content).to eq "NIST SP 800-12 fpd"
        end
      end

      it "get NIST IR 7916" do
        VCR.use_cassette "nist_ir_7916" do
          result = Relaton::Nist::Bibliography.get "NIST IR 7916"
          expect(result.docidentifier.first.content).to eq "NIST IR 7916"
        end
      end

      it "get NIST SP 500-183" do
        VCR.use_cassette "nist_sp_500_183" do
          result = Relaton::Nist::Bibliography.get "NIST SP 500-183"
          expect(result.docidentifier.first.content).to eq "NIST SP 500-183"
        end
      end

      it "Addendum" do
        VCR.use_cassette "sp_800_38a_addendum" do
          bib = Relaton::Nist::Bibliography.get "NIST SP 800-38a Add"
          expect(bib.docidentifier[0].content).to eq "NIST SP 800-38A Add."
        end
      end

      it "get incomplete reference", vcr: { cassette_name: "nist_sp_800_60v1" } do
        bib = Relaton::Nist::Bibliography.get "NIST SP 800-60v1"
        expect(bib.docidentifier[0].content).to eq "NIST SP 800-60v1r1 fpd"
      end

      context "warns when" do
        it "a code matches a resource but the year does not" do
          VCR.use_cassette "8200_wrong_year" do
            expect do
              Relaton::Nist::Bibliography.get("NISTIR 8200", "2017", {})
            end.to output(
              /\[relaton-nist\] INFO: \(NIST IR 8200\) Not found\./,
            ).to_stderr_from_any_process
          end
        end

        it "contains EP at the end" do
          expect { Relaton::Nist::Bibliography.get "NIST FIPS 201 EP" }.to output(
            /\[relaton-nist\] INFO: \(NIST FIPS 201 EP\) Not found\./,
          ).to_stderr_from_any_process
        end
      end

      context "short citation" do
        context "without stage get" do
          it "undated reference", vcr: { cassette_name: "nist_sp_800_162" } do
            result = Relaton::Nist::Bibliography.get("NIST SP 800-162")
            expect(result.id).to eq "NISTSP800162fpd"
          end

          it "final without updated-date", vcr: { cassette_name: "nist_sp_800_162_2014_01" } do
            result = Relaton::Nist::Bibliography.get "NIST SP 800-162 (January 2014)"
            expect(result.id).to eq "NISTSP800162fpd"
          end
        end

        context "with stage get" do
          it "draft with initial iteration", vcr: "nist_sp_800_37r2" do
            result = Relaton::Nist::Bibliography.get("NIST SP 800-37r2 (IPD)")
            file_path = "spec/fixtures/nist_sp_800_27r2.xml"
            xml = result.to_xml bibdata: true
            File.write file_path, xml, encoding: "UTF-8" unless File.exist? file_path
            expect(xml).to be_equivalent_to(
              File.open(file_path, "r:UTF-8", &:read)
                .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, ::Date.today.to_s),
            )
          end
        end
      end
    end
  end

  context "fetch from pubs-export", vcr: "json_data" do
    before do
      # Force to download pubs-export.zip
      allow(File).to receive(:exist?).with(Relaton::Nist::PubsExport::DATAFILE).and_return false
      allow(File).to receive(:exist?).and_call_original
    end

    it "a code with an year form json" do
      expect do
        result = Relaton::Nist::Bibliography.get "NIST FIPS 140-2", "2002"
        expect(result.id).to eq "NISTFIPS1402Upd2fpd"
      end.to output(
        match(/\[relaton-nist\] INFO: \(NIST FIPS 140-2\) Fetching from csrc\.nist\.gov \.\.\./)
          .and(match(/\[relaton-nist\] INFO: \(NIST FIPS 140-2\) Found: `NIST FIPS 140-2\/Upd2 fpd`/)),
      ).to_stderr_from_any_process
    end

    it "DRAFT" do
      result = Relaton::Nist::Bibliography.get("NIST SP 800-189(2PD)").to_xml bibdata: true
      file_path = "spec/fixtures/draft.xml"
      File.write file_path, result, encoding: "UTF-8" unless File.exist? file_path
      expect(result).to be_equivalent_to File.open(
        file_path, "r:UTF-8", &:read
      ).gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, ::Date.today.to_s)
      schema = Jing.new "grammars/relaton-nist-compile.rng"
      errors = schema.validate file_path
      expect(errors).to eq []
    end

    it "RETIRED DRAFT" do
      result = Relaton::Nist::Bibliography.get("NIST SP 800-80(IPD)").to_xml bibdata: true
      file_path = "spec/fixtures/retired_draft.xml"
      File.write file_path, result, encoding: "UTF-8" unless File.exist? file_path
      expect(result).to be_equivalent_to File.open(
        file_path, "r:UTF-8", &:read
      ).gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, ::Date.today.to_s)
      schema = Jing.new "grammars/relaton-nist-compile.rng"
      errors = schema.validate file_path
      expect(errors).to eq []
    end

    it "DRAFT OBSOLETE" do
      result = Relaton::Nist::Bibliography.get("NIST SP 800-189(2PD)")
        .to_xml bibdata: true
      file_path = "spec/fixtures/draft_obsolete.xml"
      File.write file_path, result, encoding: "UTF-8" unless File.exist? file_path
      expect(result).to be_equivalent_to File.open(file_path, "r:UTF-8", &:read)
        .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, ::Date.today.to_s)
      schema = Jing.new "grammars/relaton-nist-compile.rng"
      errors = schema.validate file_path
      expect(errors).to eq []
    end

    it "doc with issued & published dates" do
      result = Relaton::Nist::Bibliography.get("NIST SP 800-162", nil, {})
        .to_xml bibdata: true
      file_path = "spec/fixtures/issued_published_dates.xml"
      File.write file_path, result, encoding: "UTF-8" unless File.exist? file_path
      expect(result).to be_equivalent_to(
        File.open(file_path, "r:UTF-8", &:read)
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, ::Date.today.to_s),
      )
      schema = Jing.new "grammars/relaton-nist-compile.rng"
      errors = schema.validate file_path
      expect(errors).to eq []
    end

    it "doc with full issued date" do
      result = Relaton::Nist::Bibliography.get("NIST SP 1800-10(IPD)")
      xml = result.to_xml bibdata: true
      file = "spec/fixtures/full_issued_date.xml"
      File.write file, xml, encoding: "UTF-8" unless File.exist? file
      expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
        .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, ::Date.today.to_s)
      schema = Jing.new "grammars/relaton-nist-compile.rng"
      errors = schema.validate file
      expect(errors).to eq []
    end

    it "doc with edition" do
      result = Relaton::Nist::Bibliography.get "NIST FIPS 140-2"
      expect(result.edition.content).to eq "Revision 2"
    end

    it "doc with supersedes" do
      result = Relaton::Nist::Bibliography.get "NIST FIPS 140-2"
      expect(result.relation.first).to be_instance_of(
        Relaton::Nist::Relation,
      )
      expect(result.relation.first.type).to eq "obsoletes"
      expect(result.relation.first.description.content).to eq "supersedes"
    end

    it "draft active" do
      result = Relaton::Nist::Bibliography.get "NIST SP 800-140 (IPD)"
      expect(result.status.stage.content).to eq "draft-public"
      expect(result.status.substage.content).to eq "withdrawn"
    end

    it "get NIST SP 800-55 Rev. 1" do
      result = Relaton::Nist::Bibliography.get "NIST SP 800-55 Rev. 1"
      expect(result.contributor.last.person.affiliation).to be_none
    end

    it "get CSWP" do
      bib = Relaton::Nist::Bibliography.get "NIST CSWP 16 (IPD)"
      xml = bib.to_xml bibdata: true
      file = "spec/fixtures/cswp.xml"
      File.write file, xml, encoding: "UTF-8" unless File.exist? file
      expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
        .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, ::Date.today.to_s)
    end

    context "warns when" do
      it "search failed" do
        expect do
          Relaton::Nist::Bibliography.get("NIST SP 2222", nil, {})
        end.to output(
          /\[relaton-nist\] INFO: \(NIST SP 2222\) Not found\./,
        ).to_stderr_from_any_process
      end
    end

    context "short citation" do
      context "without stage get" do
        it "final where updated-date > original-release-date" do
          result = Relaton::Nist::Bibliography.get("NIST SP 800-162 (February 25, 2019)")
          expect(result.id).to eq "NISTSP800162fpd"
        end
      end

      context "with stage get" do
        it "draft without updated-date" do
          result = Relaton::Nist::Bibliography.get("NIST SP 800-205 (February 2019) (IPD)")
          expect(result.id).to eq "NISTSP800205ipd"
        end

        it "draft with 2rd iteration" do
          result = Relaton::Nist::Bibliography.get "NIST SP 800-57pt2r1 (2PD)"
          expect(result.title.first.content).to eq(
            "Recommendation for Key Management - Part 2: Best Practices for " \
            "Key Management Organizations",
          )
          expect(result.status.iteration).to eq "2"
        end

        it "final draft" do
          result = Relaton::Nist::Bibliography.get "NIST SP 800-37r2 (FPD)"
          expect(result.title.first.content).to eq(
            "Risk Management Framework for Information Systems and " \
            "Organizations - A System Life Cycle Approach for Security and " \
            "Privacy",
          )
          expect(result.status.iteration).to eq "final"
        end
      end
    end

    it "NIST SP 800-154" do
      result = Relaton::Nist::Bibliography.get "NIST SP 800-154"
      expect(result.docidentifier.first.content).to eq "NIST SP 800-154 ipd"
    end
  end
end
