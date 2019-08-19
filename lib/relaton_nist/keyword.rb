module RelatonNist
  class Keyword
    include RelatonBib

    # @return [Nokogiri::XML::DocumentFragment]
    attr_reader :element

    # @param element [String]
    def initialize(element)
      @element = Nokogiri::XML.fragment element
    end

    # @param builder [Nokogiri::XML::Builder]
    def to_xml(builder)
      builder.keyword element.to_xml
    end

    # @return [String]
    def to_hash
      element.text
    end
  end
end
