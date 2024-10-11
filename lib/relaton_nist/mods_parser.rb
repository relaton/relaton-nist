module RelatonNist
  class ModsParser
    RELATION_TYPES = {
      "otherVersion" => "editionOf",
      "preceding" => "updates",
      "succeeding" => "updatedBy",
    }.freeze

    ATTRS = %i[type docid title link abstract date doctype contributor relation place series].freeze

    def initialize(doc, series)
      @doc = doc
      @series = series
    end

    # @return [RelatonNist::NistBibliographicItem]
    def parse
      args = ATTRS.each_with_object({}) do |attr, hash|
        hash[attr] = send("parse_#{attr}")
      end
      NistBibliographicItem.new(**args)
    end

    def parse_type
      "standard"
    end

    # @return [Array<RelatonBib::DocumentIdentifier>]
    def parse_docid
      [
        { type: "NIST", id: pub_id, primary: true },
        { type: "DOI", id: parse_doi },
      ].map { |id| RelatonBib::DocumentIdentifier.new(**id) }
    end

    # @return [String]
    def pub_id
      get_id_from_str parse_doi
    end

    def get_id_from_str(str)
      ::Pubid::Nist::Identifier.parse(str).to_s
    rescue ::Pubid::Core::Errors::ParseError
      str.gsub(".", " ").sub(/^[\D]+/, &:upcase)
    end

    # @return [String]
    def replace_wrong_doi(id)
      case id
      when "NBS.CIRC.sup" then "NBS.CIRC.24e7sup"
      when "NBS.CIRC.supJun1925-Jun1926" then "NBS.CIRC.24e7sup2"
      when "NBS.CIRC.supJun1925-Jun1927" then "NBS.CIRC.24e7sup3"
      when "NBS.CIRC.24supJuly1922" then "NBS.CIRC.24e6sup"
      when "NBS.CIRC.24supJan1924" then "NBS.CIRC.24e6sup2"
      else id
      end
    end

    def parse_doi
      url = @doc.location.reduce(nil) { |m, l| m || l.url.detect { |u| u.usage == "primary display" } }
      id = remove_doi_prefix(url.content)
      replace_wrong_doi(id)
    end

    def remove_doi_prefix(id)
      id.match(/10\.6028\/(.+)/)[1]
    end

    # @return [Array<RelatonBib::TypedTitleString>]
    def parse_title
      title = @doc.title_info.reduce([]) do |a, ti|
        next a if ti.type == "alternative"

        a += ti.title.map { |t| create_title(t, "title-main", ti.non_sort[0]) }
        a + ti.sub_title.map { |t| create_title(t, "title-part") }
      end
      if title.size > 1
        content = title.map { |t| t.title.content }.join(" - ")
        title << create_title(content, "main")
      elsif title.size == 1
        title[0].instance_variable_set :@type, "main"
      end
      title
    end

    def create_title(title, type, non_sort = nil)
      content = title.gsub("\n", " ").squeeze(" ").strip
      content = "#{non_sort.content}#{content}".squeeze(" ") if non_sort
      RelatonBib::TypedTitleString.new content: content, type: type, language: "en", script: "Latn"
    end

    def parse_link
      @doc.location.map do |location|
        url = location.url.first
        type = url.usage == "primary display" ? "doi" : "src"
        RelatonBib::TypedUri.new content: url.content, type: type
      end
    end

    def parse_abstract
      @doc.abstract.map do |a|
        content = a.content.gsub("\n", " ").squeeze(" ").strip
        RelatonBib::FormattedString.new content: content, language: "en", script: "Latn"
      end
    end

    def parse_date
      date = @doc.origin_info[0].date_issued.map do |di|
        create_date(di, "issued")
      # end + @doc.record_info[0].record_creation_date.map do |rcd|
      #   create_date(rcd, "created")
      # end + @doc.record_info[0].record_change_date.map do |rcd|
      #   create_date(rcd, "updated")
      end
      date.compact
    end

    def create_date(date, type)
      RelatonBib::BibliographicDate.new type: type, on: decode_date(date)
    rescue Date::Error
    end

    def decode_date(date)
      if date.encoding == "marc" && date.content.size == 6
        Date.strptime(date.content, "%y%m%d").to_s
      elsif date.encoding == "iso8601"
        Date.strptime(date.content, "%Y%m%d").to_s
      else date.content
      end
    end

    def parse_doctype
      RelatonBib::DocumentType.new(type: "standard")
    end

    def parse_contributor
      # eaxclude primary contributors to avoid duplication
      @doc.name.reject { |n| n.usage == "primary" }.map do |name|
        entity, default_role = create_entity(name)
        next unless entity

        role = name.role.reduce([]) do |a, r|
          a + r.role_term.map { |rt| { type: rt.content } }
        end
        role << { type: default_role } if role.empty?
        RelatonBib::ContributionInfo.new entity: entity, role: role
      end.compact
    end

    def create_entity(name)
      case name.type
      when "personal" then [create_person(name), "author"]
      when "corporate" then [create_org(name), "publisher"]
      end
    end

    def create_person(name)
      # exclude typed name parts because they are not actual name parts
      cname = name.name_part.reject(&:type).map(&:content).join(" ")
      complatename = RelatonBib::LocalizedString.new cname, "en"
      fname = RelatonBib::FullName.new completename: complatename
      name_id = name.name_identifier[0]
      identifier = RelatonBib::PersonIdentifier.new "uri", name_id.content if name_id
      RelatonBib::Person.new name: fname, identifier: [identifier]
    end

    def create_org(name)
      names = name.name_part.reject(&:type).map { |n| n.content.gsub("\n", " ").squeeze(" ").strip }
      url = name.name_identifier[0]&.content
      id = RelatonBib::OrgIdentifier.new "uri", url if url
      RelatonBib::Organization.new name: names, identifier: [id]
    end

    def parse_relation
      @doc.related_item.reject { |ri| ri.type == "series" }.map do |ri|
        type = RELATION_TYPES[ri.type]
        RelatonBib::DocumentRelation.new(type: type, bibitem: create_related_item(ri))
      end
    end

    def create_related_item(item)
      item_id = get_id_from_str related_item_id(item)
      docid = RelatonBib::DocumentIdentifier.new type: "NIST", id: item_id
      fref = RelatonBib::FormattedRef.new content: item_id
      NistBibliographicItem.new(docid: [docid], formattedref: fref)
    end

    def related_item_id(item)
      if item.other_type && item.other_type[0..6] == "10.6028"
        item.other_type
      else
        item.name[0].name_part[0].content
      end => id
      replace_wrong_doi remove_doi_prefix(id)
    end

    def parse_place
      @doc.origin_info.select { |p| p.event_type == "publisher"}.map do |p|
        place = p.place[0].place_term[0].content
        /(?<city>\w+), (?<state>\w+)/ =~ place
        RelatonBib::Place.new city: city, region: create_region(state)
      end
    end

    def create_region(state)
      [RelatonBib::Place::RegionType.new(iso: state)]
    rescue ArgumentError
      []
    end

    def parse_series
      @doc.related_item.select { |ri| ri.type == "series" }.map do |ri|
        tinfo = ri.title_info[0]
        tcontent = tinfo.title[0].strip
        title = RelatonBib::TypedTitleString.new content: tcontent
        RelatonBib::Series.new title: title, number: tinfo.part_number[0]
      end
    end
  end
end
