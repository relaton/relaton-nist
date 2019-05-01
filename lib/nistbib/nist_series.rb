module NistBib
  class NistSeries
    ABBREVIATIONS = {
      "NISTIR" => "NIST Interagency/Internal Report",
      "NIST SP" => "NIST Special Publication",
      "NIST FIPS" => "NIST Federal Information Processing Standards",
    }.freeze

    # @return [String]
    attr_reader :type

    # @return [String]
    attr_reader :title

    # @return [RalatonBib::LocalizedString, NilClass]
    attr_reader :abbreviation

    # @param abbreviation [RelatonBib::LocalizedString, NilClass]
    def initialize(abbreviation)
      @type = "main"
      @abbreviation = RelatonBib::LocalizedString.new(
        abbreviation.downcase.gsub(" ", "-"), "en", "Latn"
      )
      @title = ABBREVIATIONS[abbreviation]
    end

    # @param builder [Nokogiri::XML::Builder]
    def to_xml(builder)
      builder.series type: type do
        builder.title title
        builder.abbreviation { abbreviation.to_xml builder } if abbreviation
      end
    end
  end
end
