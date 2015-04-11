
require "i_dig_sql/H"
require "i_dig_sql/parse"

class I_Dig_Sql

  include Enumerable

  HAS_VAR = /(\{\{|\<\<)[^\}\>]+(\}\}|\>\>)/
  SELECT_FROM_REG = /SELECT.+FROM.+/


  ALL_UNDERSCORE   = /\A[_]+\Z/
  COMBO_LEFT_RIGHT = [:left, :left, :right, :right]
  COMBO_OUT_IN     = [:out, :in, :out, :in]

  Duplicate = Class.new RuntimeError

  class << self
  end # === class self ===

  attr_reader :digs, :WITHS, :data
  def initialize *args
    @WITH     = nil
    @FRAGMENT = nil
    @SQL      = nil
    @WITHS    = []

    @digs  = []
    @data  = H.new(:allow_update)
    .merge!(
      :name =>nil,
      :raw  =>nil,
      :vars =>H.new
    )

    args.each { |a|

      case a

      when Symbol
        @data[:name] = a

      when I_Dig_Sql
        @digs << a

      when String
        tables = self.class.parse(a)
        if tables.size == 1 && tables.first[:raw]
          @data.merge! tables.first
        else
          tables.map { |t|
            self[t[:name]] = t
          }
        end

      when Hash, H
        if a.has_key?(:raw) || a.has_key?(:unparsed) || a.has_key?(:in) || a.has_key?(:real_table)
          @data.merge! a
        else
          @data[:vars].merge! a
        end

      else
        fail ArgumentError, "Unknown arg: #{a.inspect}"

      end  # === case

    }

  end # === def initialize

  %w{name in out raw vars}.each { |k|
    eval <<-EOF.strip, nil, __FILE__, __LINE__
      def #{k}
        @data[:#{k}]
      end
    EOF
  }

  def real_table
    if @data[:real_table] == :DEFAULT
      self[:DEFAULT].data[:real_table]
    else
      @data[:real_table]
    end
  end

  def vars!
    vars = H.new.merge!(@data[:vars])

    @digs.reverse.inject(vars) { |memo, dig|
      if dig != self
        memo.merge! dig.vars
      end
      memo
    }
  end

  def has_key? name
    !!(search name)
  end

  def search name
    fail ArgumentError, "No name specified: #{name.inspect}" if !name
    return self if self.name == name
    found = false
    @digs.reverse.detect { |d|
      found = if d.name == name
                d
              else
                d.digs.detect { |deep|
                  deep.name == name
                }
              end
    }
    found
  end

  def [] name
    found = search(name)
    fail ArgumentError, "SQL not found for: #{name.inspect}" unless found
    found
  end

  def []= name, val
    fail ArgumentError, "Name already taken: #{name.inspect}" if has_key?(name)

    case val
    when String
      @digs << I_Dig_Sql.new(self, name, val)

    when Hash, H
      case
      when val[:name] == :DEFAULT
        @digs << I_Dig_Sql.new(:DEFAULT, val)
      when val[:raw]
        @data.merge! val
      else
        @digs << I_Dig_Sql.new(self, name, val)
      end

    when I_Dig_Sql
      @digs << val

    else
      fail ArgumentError, "Unknown class: #{name.inspect} -> #{val.class}"

    end # === case
  end

  def each
    digs = @digs.reverse
    digs.unshift self
    if block_given?
      digs.each { |d| yield d.name, d }
    else
      digs.each
    end
  end


  def << str
    if IS_RAW(str)
      (@data[:raw] ||= "") << str
    else
      self.class.parse(str).each { |name, t|
        self[name] = t
      }
    end
  end

  def has_raw?
    !!(@data[:raw] && !@data[:raw].strip.empty?)
  end

  def to_pair
    [to_sql, vars!]
  end

  def to_meta *args
    compile *args
  end

  def to_sql *args
    compile(*args)[:SQL]
  end

  %w{ FRAGMENT SQL }.each { |k|
    eval <<-EOF.strip, nil, __FILE__, __LINE__ + 1
      def #{k}
        return @#{k} if @SQL
        to_meta[:#{k}]
      end
    EOF
  }

  private # ==========================================

  def prefix_raw sym
    "raw_#{sym.to_s.split('_').first}".to_sym
  end

  def prefix sym
    sym.to_s.split('_').first.to_sym
  end

  def table_name one, two = nil
    if two
      k = two
      link_name = one
    else
      k = one
      link_name = nil
    end

    case
    when [:out_ftable, :in_ftable].include?(k)
      "#{real_table}_#{ meta[prefix(k)] }_#{meta[k]}"

    when link? && link_name && @data[link_name][:inner_join].include?(k)
      "#{self.name}_#{@data[link_name][:name]}_#{k}"

    else
      fail ArgumentError, "Unknown key for table name: #{k.inspect}"
    end
  end

  #
  # Examples:
  #
  #   field :in, :owner_id
  #   field :screen_name, :screen_name
  #   field :in
  #   field :raw_in
  #
  protected(
    def field *args

      case args
      when [:out], [:in]
        "#{name}.#{data[args.last][:name]}"
      when [:raw, :out], [:raw, :in]
        "#{name}.#{self[:DEFAULT].data[args.last]}"
      when [:owner_id]
        "#{name}.owner_id"
      else
        fail ArgumentError, "Unknown args: #{args.inspect}"
      end # === case

    end # === def field
  )

  def table_name_to_raw key, final
    target = self[key]

    if target.is_a?(String)
      fragments_to_raw([target], final)
      return
    end

    final[:RAW] << "-- i_dig_sql: #{key.inspect}"
    final[:RAW] << meta_to_fragment(target, final)
  end

  protected def compile *args
    return(self[*args].compile) if args.first && args.first != name

    if !@SQL

      has_raw? && args.empty? ? compile_raw : compile_meta(*args)

    end

    {FRAGMENT: @FRAGMENT, SQL: @SQL, WITH: @WITH, VARS: vars!}
  end # === def to_sql

  def compile_raw
    @data[:raw].freeze

    s = @FRAGMENT = @data[:raw].dup

    while s[HAS_VAR] 
      s.gsub!(/\{\{\s?([a-zA-Z0-9\_]+)\s?\}\}/) do |match|
        key = $1.to_sym
        @WITHS << key
        key
      end

      s.gsub!(/\<\<\s?([a-zA-Z0-9\_\-\ \*]+)\s?\>\>/) do |match|
        tokens = $1.split
        key    = tokens.pop.to_sym
        field  = tokens.empty? ? nil : tokens.join(' ')

        case
        when field
          @WITHS << key
          "SELECT #{field} FROM #{key}"
        else
          self[key].to_sql
        end
      end
    end # === while s HAS_VAR

    compile_meta
  end # === fragments_to_raw

  def compile_meta
    if !@FRAGMENT
      @FRAGMENT ||= begin
                      [:SELECT, :FROM, :WHERE].inject("") { |memo, name|
                        val = self.send(name)
                        if val
                          memo << "#{name}\n  #{val}\n"
                        end
                        memo
                      }.strip
                    end

      [:ORDER_BY, :GROUP_BY, :LIMIT, :OFFSET].each { |name|
        next unless @data.has_key?(name)
        @FRAGMENT << "\n#{name.to_s.sub('_', ' ')} #{@data[name].join ', '}"
      }
    end # === if !@FRAGMENT

    @WITH = if @WITHS.empty?
              ""
            else
              %^WITH\n  #{WITH()}\n\n^
            end

    @SQL = (@WITH + @FRAGMENT).strip

    return @SQL


    case k
    when :where


    when :from

      last = nil

      (meta[:from].empty? ? [meta[:name]] : meta[:from]).each_with_index { |k, i|
        string = ""
        final[:WITH] << k
        table = self[k]

        if !last
          string << (meta[:from].empty? ? "link AS #{k}" : k.to_s)

          [:out_ftable, :in_ftable].each { |ftable|
            if meta[ftable]
              final[:WITH] << meta[ftable]
              string << %^\n  LEFT JOIN #{meta[ftable]} AS #{table_name meta, ftable}^
              string << %^\n    ON #{field meta, prefix_raw(ftable)} = #{meta[ftable]}.id^
            end
          }

        else
          string << %^\n  INNER JOIN #{table[:name]}\n^
          string << %^    ON #{ field last, :in } = #{ field table, :out }^
        end # === if !last

        sql[:FROM] << string
        last = table

      } # === meta each_with_index

    when :order_by
      sql[:ORDER_BY].concat(
        meta[:order_by].map { |unknown|
          case unknown
          when Array
            unknown.join ' '.freeze
          when String
            unknown
          else
            fail ArgumentError, "Unknown type for :order_by: #{unknown.class}"
          end
        }
      )

    when :group_by
      sql[:GROUP_BY].concat meta[:group_by]

    else
      fail "Programmer Error: unknown key #{k.inspect}"

    end # === each

    s = ""
    s << %^SELECT\n  #{sql[:SELECT].join ",\n  "}\n^
    s << %^FROM\n  #{sql[:FROM].join "\n  "}\n^

    if !sql[:WHERE].empty?
      s << %^WHERE\n  #{sql[:WHERE].join "\n  AND\n"}\n^
    end

    if !sql[:ORDER_BY].empty?
      s << %^ORDER BY #{sql[:ORDER_BY].join ", "}\n^
    end

    if !sql[:GROUP_BY].empty?
      s << %^GROUP BY #{sql[:GROUP_BY].join ", "}\n^
    end

    s
  end # === def compile_meta

  def WITH
    withs = @WITHS.dup
    maps  = []
    done  = {}
    while name = withs.shift
      next if done[name]
      if name == :DEFAULT || !self.has_key?(name)
        done[name] = true
        next
      end

      fragment = self[name].FRAGMENT
      fragment.gsub!(/^/, "    ") if ENV['IS_DEV']
      maps << "#{name} AS (\n#{fragment}\n  )"
      withs.concat self[name].WITHS
      done[name] = true
    end # === while name

    maps.join ",\n  "
  end

  def SELECT
    selects = @data[:SELECT]
    if selects.empty?
      "*"
    else
      selects.join ",\n  "
    end
  end # === def SELECT

  def FROM
    froms = @data[:FROM].dup

    if froms.empty?
      froms << real_table
    end

    froms.each { |name|
      @WITHS << name if name.is_a?(Symbol)
    }

    if link?
      [:out, :in].each { |link_name|
        joins = @data[link_name][:inner_join]
        if link_name == :out && joins.size == 2
          keys = [[:owner_id], [:raw, link_name]]
        else
          keys = [[:raw, link_name]]
        end
        if joins
          joins.each { |join_name|
            froms << (
              %^  INNER JOIN {{#{join_name}}} AS #{table_name(link_name, join_name)}\n^.<<(
                %^    ON #{field(*(keys.shift))} = #{join_name}.id^
              )
            )
          }
        end
      }

      aputs @data

    end # === if link?

    return nil if froms.empty?

    last   = nil
    string = ""
    while u = froms.shift
      n = froms.first
      if last && u.is_a?(String)
        string << "\n#{u}"
      elsif last && last.is_a?(Symbol) && u.is_a?(Symbol)
        string << ",\n" << u.to_s
      else
        string << u.to_s
      end
      last = u
    end

    string
  end # === def FROM

  def link?
    @data[:in] && @data[:out]
  end

  def WHERE
    wheres = @data[:WHERE]

    if @data.has_key?(:OF)
      table = self[@data[:FROM].first]
      wheres << "#{table.field(:out)} = #{@data[:OF].first}"
    end

    if false && @data[:NOT_EXISTS]
      block = self[meta[:not_exists]]
      w = ""
      w << %^  NOT EXISTS (\n^
      w << %^    SELECT 1\n^
      w << %^    FROM #{meta[:not_exists]}\n^
      w << %^    WHERE\n^

      conds = []
      block[:where].each { |block_meta|
        type_id = block_meta.first
        c = ""
        c << %^    (\n^
        c << "      #{field meta, block_meta[1][1], block_meta[1][2]} = #{field block, block_meta[2][1], block_meta[2][2]}\n"
        c << "      AND\n"
        c << "      #{meta[:not_exists]}.type_id = :#{type_id}_TYPE_ID\n"
        c << "      AND\n"
        c << "      #{field meta, block_meta[3][1], block_meta[3][2]} = #{field block, block_meta[4][1], block_meta[4][2]}\n"
        c << %^    )\n^
        conds << c
      }

      w << conds.join("    OR\n")
      sql[:WHERE] << w
    end


    return nil if wheres.empty?
    wheres.join " AND "
  end

  def with_to_raw final
    withs    = final[:WITH].dup
    used     = []
    compiled = []

    while k = withs.shift
      next if used.include?(k)

      size = withs.size
      case k
      when Symbol
        withs.unshift self[k]

      when I_Dig_Sql
        compiled << %^#{k.name} AS ( #{k.raw} )^
      else
        fail ArgumentError, "Unknown type for :WITH: #{k.class}"
      end

      used << k

      if size != final[:WITH].size
        withs.concat final[:WITH]
      end
    end # === while

    final[:WITH!] = compiled

  end # === def with_to_raw

  # === END: Rendering DSL ==========================================

end # === class I_Dig_Sql ===



