module NistBib
  class NistBibliographicItem < RelatonBib::BibliographicItem
    # @return [NistBib::NistSeries, NilClass]
    attr_reader :nistseries

    # @return [Array<NistBib::Keyword>]
    attr_reader :keyword

    # @return [NistBib::CommentPeriod]
    attr_reader :commentperiod

    # @param title [Array<RelatonBib::TypedTitleString>]
    # @param formattedref [RelatonBib::FormattedRef, NilClass]
    # @param type [String, NilClass]
    # @param docid [Array<RelatonBib::DocumentIdentifier>]
    # @param docnumber [String, NilClass]
    # @param language [Arra<String>]
    # @param script [Array<String>]
    # @param docstatus [RelatonBib::DocumentStatus, NilClass]
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
    #
    # @param nistseries [Nist::NistSeries, NilClass]
    def initialize(**args)
      super
      @nistseries = args[:nistseries]
      @keyword = args.fetch :keyword, []
      @commentperiod = args[:commentperiod]
    end

    # @param builder [Nokogiri::XML::Builder]
    def to_xml(builder = nil)
      super builder, "bibitem" do |b|
        nistseries&.to_xml b
        keyword.each { |kw| kw.to_xml b }
        commentperiod&.to_xml b
      end
    end
  end
end
