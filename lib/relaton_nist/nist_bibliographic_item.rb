module RelatonNist
  class NistBibliographicItem < RelatonBib::BibliographicItem
    # @return [Array<RelatonNist::Keyword>]
    # attr_reader :keyword

    # @return [RelatonNist::CommentPeriod, nil]
    attr_reader :commentperiod

    # @param id [String, nil]
    # @param title [Array<RelatonBib::TypedTitleString>]
    # @param formattedref [RelatonBib::FormattedRef, nil]
    # @param type [String, nil]
    # @param docid [Array<RelatonBib::DocumentIdentifier>]
    # @param docnumber [String, nil]
    # @param language [Arra<String>]
    # @param script [Array<String>]
    # @param docstatus [RelatonNist::DocumentStatus, nil]
    # @param edition [String, nil]
    # @param version [RelatonBib::BibliographicItem::Version, nil]
    # @param biblionote [Array<RelatonBib::FormattedStrong>]
    # @param series [Array<RelatonBib::Series>]
    # @param medium [RelatonBib::Medium, NilClas]
    # @param place [Array<String>]
    # @param extent [Array<Relaton::BibItemLocality>]
    # @param accesslocation [Array<String>]
    # @param classification [RelatonBib::Classification, nil]
    # @param validity [RelatonBib:Validity, nil]
    # @param fetched [Date, nil] default nil
    # @param doctype [RelatonBib::DocumentType, nil]
    # @param keyword [Array<RelatonBib::Keyword>]
    # @param commentperiod [RelatonNist::CommentPeriod, nil]
    #
    # @param date [Array<Hash>]
    # @option date [String] :type
    # @option date [String] :from
    # @option date [String] :to
    #
    # @param contributor [Array<Hash>]
    # @option contributor [String] :type
    # @option contributor [String] :from
    # @option contributor [String] :to
    # @option contributor [String] :abbreviation
    # @option contributor [Array<String>] :role
    #
    # @param abstract [Array<Hash>]
    # @option abstract [String] :content
    # @option abstract [String] :language
    # @option abstract [String] :script
    # @option abstract [String] :type
    #
    # @param relation [Array<Hash, RelatonNist::DocumentRelation>]
    # @option relation [String] :type
    # @option relation [RelatonBib::BibliographicItem] :bibitem
    # @option relation [Array<RelatonBib::BibItemLocality>] :bib_locality
    def initialize(**args)
      # @doctype = args.delete(:doctype) || "standard"
      # args[:doctype] ||= "standard"
      # @keyword = args.delete(:keyword) || []
      @commentperiod = args.delete :commentperiod
      super
    end

    #
    # Fetch flavor schema version
    #
    # @return [String] schema version
    #
    def ext_schema
      @ext_schema ||= schema_versions["relaton-model-nist"]
    end

    # @param hash [Hash]
    # @return [RelatonNist::GbBibliographicItem]
    def self.from_hash(hash)
      item_hash = RelatonNist::HashConverter.hash_to_bib(hash)
      new(**item_hash)
    end

    # @param opts [Hash]
    # @option opts [Nokogiri::XML::Builder] :builder XML builder
    # @option opts [Boolean] :bibdata
    # @option opts [String] :lang language
    # @return [String] XML
    def to_xml(**opts)
      super date_format: :short, **opts do |b|
        if opts[:bibdata]
          ext = b.ext do
            doctype&.to_xml b
            commentperiod&.to_xml b
          end
          ext["schema-version"] = ext_schema unless opts[:embedded]
        end
      end
    end

    # @param embedded [Boolean] embedded in another document
    # @return [Hash]
    def to_hash(embedded: false)
      hash = super
      # hash["keyword"] = single_element_array(keyword) if keyword&.any?
      hash["ext"]["commentperiod"] = commentperiod.to_hash if commentperiod
      hash
    end

    def has_ext?
      super || commentperiod
    end

    # @param prefix [String]
    # @return [String]
    def to_asciibib(prefix = "")
      out = super
      out += commentperiod.to_asciibib prefix if commentperiod
      out
    end

    #
    # Create BibXML reference attributes
    #
    # @return [Hash<Symbol=>String>] attributes
    #
    def ref_attrs
      docidentifier.detect(&:primary)&.tap do |di|
        return { anchor: di.id.gsub(" ", ".").squeeze(".") }
      end
    end
  end
end
