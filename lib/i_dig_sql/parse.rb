
class I_Dig_Sql

  NEW_LINE             = "\n"
  IS_COMMENT_REGEXP    = /\A\s*\#/
  IS_FIELD_LIST_REGEXP = /\A[a-z0-9\_\ \,]+\Z/
  IS_COMBO_REGEXP      = /[_]{2,}.+\|.+[_]{2,}/
  SINGLE_PIPE          = /[^\|]\|[^\|]/
  COMMA                = ","
  NOT_EXISTS_REGEXP    = /(NOT\s+EXISTS\s+)/
  ORDER_BY_REGEXP      = /ORDER\s+BY\s+/
  GROUP_BY_REGEXP      = /GROUP\s+BY\s+/
  UPCASE_START         = /\A[A-Z]/
  DOWNCASE_START       = /\A[^A-Z]/
  CLAUSES              = %w{ FROM OF SELECT }

  module Helpers

    def IS_COMBO l
      l[IS_COMBO_REGEXP]
    end

    def IS_FIELD_LIST l
      l[IS_FIELD_LIST_REGEXP]
    end

    def IS_COMMENT l
      l[IS_COMMENT_REGEXP]
    end

    def IS_EMPTY l
      l && l.strip.empty?
    end

    def NOT_EXISTS(l)
      l[NOT_EXISTS_REGEXP]
    end

    def IS_RAW l
      l[SELECT_FROM_REG] || l[HAS_VAR]
    end

  end # === module Helpers

  include Helpers

  class << self

    include Helpers

    def parse name, str = nil
      if name && !str
        str  = name
        name = nil
      end

      if IS_RAW(str)
        val = {:raw=>str}
        if name
          val[:name] = name
        end

        return [val]
      end

      blocks = []
      last   = nil
      lines  = str.split(NEW_LINE)

      while l = lines.shift
        is_empty   = IS_EMPTY(l)
        is_comment = IS_COMMENT(l)
        case
        when is_empty && last
          fail "not ready"
        when is_empty && !last
          next
        when is_comment
          next
        else
          b = [l.strip]
          while lines.first && !IS_EMPTY(lines.first)
            l = lines.shift
            (b << l.strip) unless IS_COMMENT(l)
          end
          blocks << b
        end
      end # === while

      tables = {}

      blocks.each { |b|

        if name
          first  = name
          pieces = []
        else
          first  = b.shift
          pieces = first.split
        end

        case

        when first.is_a?(Symbol)
          tables[first] = {
            :name       => first,
            :real_table => first,
            :unparsed   => b
          }

        when pieces.size == 1
          tables[first.to_sym] = {
            :name       => first.to_sym,
            :real_table => first.to_sym,
            :unparsed   => b
          }

        when first['DEFAULT']
          fields = b.shift.split('|').map(&:strip)
          fail ArgumentError, "Unknown options: #{b.inspect}" if !b.empty?

          t = {
            :name     => pieces.first,
            :out      => fields.first.to_sym,
            :in       => fields.last.to_sym,
            :unparsed => []
          }

          tables[:DEFAULT] = t

        when pieces.size == 3 && first[' AS ']
          tables[pieces.last.to_sym] = {
            :name       => pieces.last.to_sym,
            :real_table => pieces.first.to_sym,
            :unparsed   => b
          }

        else
          fail "Programmer Error: unknown parsing rule for: #{first.inspect}"

        end # === case
      }

      tables.each { |name, meta|
        meta[:out] ||= {}
        meta[:in]  ||= {}
        has_out_in = false
        while meta[:unparsed] && l = meta[:unparsed].shift
          case

            #  field_1, field_2 , ...
          when IS_FIELD_LIST(l) && meta[:unparsed].empty?
            meta[:SELECT] = l.split(',')

            # out | in
          when ((pieces = l.split('|')) && pieces.size == 2) && !has_out_in
            meta[:out][:name], meta[:in][:name] = pieces.map(&:strip).map(&:to_sym)
            has_out_in = true

            # inner_join_table_names | inner_join_table_name
          when ((pieces = l.split(SINGLE_PIPE)) && pieces.size == 2) && meta[:out] && meta[:in]
            meta[:out][:inner_join] = pieces.first.split(COMMA).map(&:strip).map(&:to_sym)
            meta[:in][:inner_join]  = pieces.last.split(COMMA).map(&:strip).map(&:to_sym)
            if meta[:name] == meta[:real_table] && tables[:DEFAULT]
              meta[:real_table] = tables[:DEFAULT][:name]
            end

          when ((pieces = l.split('||')) && pieces.size == 2)
            meta[:type_id] = pieces.map(&:strip).map(&:to_sym)

            #  ___ field | field ___
          when (IS_COMBO(l))
            meta[:combos] ||= []
            meta[:combos] << l

            #    NOT  EXISTS   name
          when NOT_EXISTS(l)
            (meta[:NOT_EXISTS] ||= []).concat l.split(NOT_EXISTS_REGEXP).last.split.map(&:to_sym)

          when l[ORDER_BY_REGEXP]
            (meta[:ORDER_BY] ||= []).concat l.split(ORDER_BY_REGEXP).last.split(COMMA).map(&:strip)

          when l[GROUP_BY_REGEXP]
            (meta[:GROUP_BY] ||= []).concat l.split(GROUP_BY_REGEXP).last.split(COMMA).map(&:strip)

          when CLAUSES.include?(clause = l.split.first)

            (meta[clause.to_sym] ||= [])
            tail = l.split(clause).last

            if tail
              meta[clause.to_sym].concat(
                tail.
                split(COMMA).
                map(&:strip).
                map(&:to_sym)
              )
            end

            while meta[:unparsed].first && meta[:unparsed].first[DOWNCASE_START]
              (meta[clause.to_sym] ||= []) << meta[:unparsed].shift
            end

          else
            fail "Programmer Error: Parsing rule not found for: #{l.inspect}"

          end # === case
        end # === while

        meta[:out] = nil if meta[:out].empty?
        meta[:in]  = nil if meta[:in].empty?

      } # === tables each

      tables
    end # === def parse

  end # === class << self

end # === I_Dig_Sql
