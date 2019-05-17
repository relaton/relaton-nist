module NistBib
  class NistBibliographicItem < RelatonBib::BibliographicItem
    # @return [String]
    attr_reader :doctype

    # @return [Array<NistBib::Keyword>]
    attr_reader :keyword

    # @return [NistBib::CommentPeriod]
    attr_reader :commentperiod

    # @param id [String, NilClass]
    # @param title [Array<RelatonBib::TypedTitleString>]
    # @param formattedref [RelatonBib::FormattedRef, NilClass]
    # @param type [String, NilClass]
    # @param docid [Array<RelatonBib::DocumentIdentifier>]
    # @param docnumber [String, NilClass]
    # @param language [Arra<String>]
    # @param script [Array<String>]
    # @param docstatus [NistBib::DocumentStatus, NilClass]
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
    # @param keyword [Array<NistBib::Keyword>]
    # @param commentperiod [NistBib::CommentPeriod]
    #
    # @param dates [Array<Hash>]
    # @option dates [String] :type
    # @option dates [String] :from
    # @option dates [String] :to
    #
    # @param contributors [Array<Hash>]
    # @option contributors [String] :type
    # @option contributors [String] :from
    # @option contributirs [String] :to
    # @option contributors [String] :abbreviation
    # @option contributors [Array<String>] :roles
    #
    # @param abstract [Array<Hash>]
    # @option abstract [String] :content
    # @option abstract [String] :language
    # @option abstract [String] :script
    # @option abstract [String] :type
    #
    # @param relations [Array<Hash>]
    # @option relations [String] :type
    # @option relations [RelatonBib::BibliographicItem] :bibitem
    # @option relations [Array<RelatonBib::BibItemLocality>] :bib_locality
    def initialize(**args)
      @doctype = "stadard"
      @keyword = args.delete(:keyword) || []
      @commentperiod = args.delete :commentperiod
      super
    end

    # @param builder [Nokogiri::XML::Builder]
    def to_xml(builder = nil, **opts)
      super builder, date_format: :short, **opts do |b|
        if opts[:bibdata]
          b.ext do
            b.doctype doctype
            keyword.each { |kw| kw.to_xml b }
            commentperiod&.to_xml b
          end
        end
      end
    end
  end
end
