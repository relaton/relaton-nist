# frozen_string_literal: true

require "pubid"
require "loc_mods"

module Relaton
  module Nist
    class ModsParser
      RELATION_TYPES = {
        "otherVersion" => "editionOf",
        "preceding" => "updates",
        "succeeding" => "updatedBy",
      }.freeze

      ATTRS = %i[type docidentifier title source abstract date contributor
                  relation place series].freeze

      def initialize(doc, series, errors = {})
        @doc = doc
        @series = series
        @errors = errors
      end

      # @return [Bib::ItemData]
      def parse
        args = ATTRS.each_with_object({}) do |attr, hash|
          hash[attr] = send("parse_#{attr}")
        end
        args[:ext] = Ext.new(doctype: parse_doctype, flavor: "nilst")
        ItemData.new(**args)
      end

      def parse_type = "standard"

      # @return [Array<Bib::Docidentifier>]
      def parse_docidentifier
        ids = [
          { type: "NIST", content: pub_id, primary: true },
          { type: "DOI", content: parse_doi },
        ].reject { |id| id[:content].nil? || id[:content].empty? }
        @errors[:docidentifier] &&= ids.empty?
        ids.map { |id| Bib::Docidentifier.new(**id) }
      end

      # @return [String]
      def pub_id = get_id_from_str parse_doi

      def get_id_from_str(str)
        return if str.nil? || str.empty?

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
        return if url.nil?

        id = remove_doi_prefix(url.content)
        return if id.nil?

        replace_wrong_doi(id)
      end

      def remove_doi_prefix(id) = id.match(/10\.6028\/(.+)/)&.send(:[], 1)

      # @return [Array<Bib::Title>]
      def parse_title
        title = @doc.title_info.reduce([]) do |a, ti|
          next a if ti.type == "alternative"

          a += ti.title.map { |t| create_title(t, "title-main", ti.non_sort&.first) }
          next a unless ti.sub_title

          a + ti.sub_title.map { |t| create_title(t, "title-part") }
        end
        if title.size > 1
          content = title.map { |t| t.content }.join(" - ")
          title << create_title(content, "main")
        elsif title.size == 1
          title[0].instance_variable_set :@type, "main"
        end
        @errors[:title] &&= title.empty?
        title
      end

      def create_title(title, type, non_sort = nil)
        content = title.gsub("\n", " ").squeeze(" ").strip
        content = "#{non_sort.content}#{content}".squeeze(" ") if non_sort
        Bib::Title.new content: content, type: type, language: "en", script: "Latn"
      end

      def parse_source
        source = @doc.location.map do |location|
          url = location.url.first
          type = url.usage == "primary display" ? "doi" : "src"
          Bib::Uri.new content: url.content, type: type
        end
        @errors[:source] &&= source.empty?
        source
      end

      def parse_abstract
        abstract = Array(@doc.abstract).map do |a|
          content = a.content.gsub("\n", " ").squeeze(" ").strip
          Bib::LocalizedMarkedUpString.new content: content, language: "en",
                                           script: "Latn"
        end
        @errors[:abstract] &&= abstract.empty?
        abstract
      end

      def parse_date
        date = @doc.origin_info[0].date_issued.map do |di|
          create_date(di, "issued")
        end.compact
        @errors[:date] &&= date.empty?
        date
      end

      def create_date(date, type)
        Date.new type: type, at: decode_date(date)
      rescue ::Date::Error
      end

      def decode_date(date)
        if date.encoding == "marc" && date.content.size == 6
          ::Date.strptime(date.content, "%y%m%d").to_s
        elsif date.encoding == "iso8601"
          ::Date.strptime(date.content, "%Y%m%d").to_s
        else date.content
        end
      end

      def parse_doctype = Doctype.new(content: "standard")

      def parse_contributor
        # exclude primary contributors to avoid duplication
        contributor = @doc.name.reject { |n| n.usage == "primary" }.map do |name|
          entity, default_role = create_entity(name)
          next unless entity

          role = (name.role || []).reduce([]) do |a, r|
            a + r.role_term.map { |rt| Bib::Contributor::Role.new(type: rt.content) }
          end
          role << Bib::Contributor::Role.new(type: default_role) if role.empty?
          create_contributor(entity, role)
        end.compact
        @errors[:contributor] &&= contributor.empty?
        contributor
      end

      def create_contributor(entity, role)
        case entity
        when Bib::Person
          Bib::Contributor.new(role: role, person: entity)
        when Bib::Organization
          Bib::Contributor.new(role: role, organization: entity)
        end
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
        completename = Bib::LocalizedString.new(content: cname, language: "en")
        fname = Bib::FullName.new(completename: completename)
        name_id = name.name_identifier&.first
        identifier = []
        if name_id
          identifier << Bib::Person::Identifier.new(type: "uri",
                                                     content: name_id.content)
        end
        Bib::Person.new(name: fname, identifier: identifier)
      end

      def create_org(name)
        names = name.name_part.reject(&:type).map do |n|
          Bib::TypedLocalizedString.new(
            content: n.content.gsub("\n", " ").squeeze(" ").strip,
          )
        end
        url = name.name_identifier&.first&.content
        identifier = []
        if url
          identifier << Bib::OrganizationType::Identifier.new(type: "uri",
                                                               content: url)
        end
        Bib::Organization.new(name: names, identifier: identifier)
      end

      def parse_relation
        relations = Array(@doc.related_item).reject { |ri| ri.type == "series" }.filter_map do |ri|
          type = RELATION_TYPES[ri.type]
          bibitem = create_related_item(ri)
          Relation.new(type: type, bibitem: bibitem) if bibitem
        end
        @errors[:relation] &&= relations.empty?
        relations
      end

      def create_related_item(item)
        item_id = get_id_from_str related_item_id(item)
        return if item_id.nil? || item_id.empty?

        docid = Bib::Docidentifier.new(type: "NIST", content: item_id)
        fref = Bib::LocalizedMarkedUpString.new(content: item_id)
        ItemData.new(docidentifier: [docid], formattedref: fref)
      end

      def related_item_id(item)
        if item.other_type && item.other_type[0..6] == "10.6028"
          item.other_type
        else
          item.name[0].name_part[0].content
        end => id
        doi = remove_doi_prefix(id)
        return if doi.nil?

        replace_wrong_doi(doi)
      end

      def parse_place
        place = @doc.origin_info.select { |p| p.event_type == "publisher" }.map do |p|
          pl = p.place[0].place_term[0].content
          /(?<city>\w+), (?<state>\w+)/ =~ pl
          Bib::Place.new(city: city, region: create_region(state))
        end
        @errors[:place] &&= place.empty?
        place
      end

      def create_region(state)
        [Bib::Place::RegionType.new(iso: state)]
      rescue ArgumentError
        []
      end

      def parse_series
        series = Array(@doc.related_item).select { |ri| ri.type == "series" }.map do |ri|
          tinfo = ri.title_info[0]
          tcontent = tinfo.title[0].strip
          title = Bib::Title.new(content: tcontent)
          Bib::Series.new(title: [title], number: tinfo.part_number&.first)
        end
        @errors[:series] &&= series.empty?
        series
      end
    end
  end
end
