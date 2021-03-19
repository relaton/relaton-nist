module RelatonNist
  class NistBibliographicItem < RelatonBib::BibliographicItem
    # @return [String]
    attr_reader :doctype

    # @return [Array<RelatonNist::Keyword>]
    # attr_reader :keyword

    # @return [RelatonNist::CommentPeriod, NilClass]
    attr_reader :commentperiod

    # @param id [String, NilClass]
    # @param title [Array<RelatonBib::TypedTitleString>]
    # @param formattedref [RelatonBib::FormattedRef, NilClass]
    # @param type [String, NilClass]
    # @param docid [Array<RelatonBib::DocumentIdentifier>]
    # @param docnumber [String, NilClass]
    # @param language [Arra<String>]
    # @param script [Array<String>]
    # @param docstatus [RelatonNist::DocumentStatus, NilClass]
    # @param edition [String, NilClass]
    # @param version [RelatonBib::BibliographicItem::Version, NilClass]
    # @param biblionote [Array<RelatonBib::FormattedStrong>]
    # @param series [Array<RelatonBib::Series>]
    # @param medium [RelatonBib::Medium, NilClas]
    # @param place [Array<String>]
    # @param extent [Array<Relaton::BibItemLocality>]
    # @param accesslocation [Array<String>]
    # @param classification [RelatonBib::Classification, NilClass]
    # @param validity [RelatonBib:Validity, NilClass]
    # @param fetched [Date, NilClass] default nil
    # @param doctype [String]
    # @param keyword [Array<RelatonBib::Keyword>]
    # @param commentperiod [RelatonNist::CommentPeriod, NilClass]
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

    # @param hash [Hash]
    # @return [RelatonNist::GbBibliographicItem]
    def self.from_hash(hash)
      item_hash = RelatonNist::HashConverter.hash_to_bib(hash)
      new **item_hash
    end

    # @param opts [Hash]
    # @option opts [Nokogiri::XML::Builder] :builder XML builder
    # @option opts [Boolean] :bibdata
    # @option opts [String] :lang language
    # @return [String] XML
    def to_xml(**opts)
      super date_format: :short, **opts do |b|
        if opts[:bibdata]
          b.ext do
            b.doctype doctype if doctype
            commentperiod&.to_xml b
          end
        end
      end
    end

    # @return [Hash]
    def to_hash
      hash = super
      # hash["keyword"] = single_element_array(keyword) if keyword&.any?
      hash["commentperiod"] = commentperiod.to_hash if commentperiod
      hash
    end

    # @param prefix [String]
    # @return [String]
    def to_asciibib(prefix = "")
      out = super
      out += commentperiod.to_asciibib prefix if commentperiod
      out
    end
  end
end
