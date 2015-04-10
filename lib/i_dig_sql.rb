
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

  attr_reader :digs, :WITHS
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

  %w{ WITH FRAGMENT SQL }.each { |k|
    eval <<-EOF.strip, nil, __FILE__, __LINE__
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

  def table_name k
    name = @data[:real_table]
    case k
    when :out_ftable, :in_ftable
      "#{name}_#{ meta[prefix(k)] }_#{meta[k]}"
    else
      fail ArgumentError, "Unknown key for table name: #{k.inspect}"
    end
  end

  #
  # Example:
  #   field :in, :owner_id
  #   field :screen_name, :screen_name
  #   field :in
  #   field :raw_in
  def field *args
    meta = @data
    case args.size

    when 2
      if args.first == :in || args.first == :out
        io, k = args
        case
        when meta[:"#{io}_has"] == k
          tname = table_name(meta, :"#{io}_ftable")
          "#{tname}.#{k}"
        when k == :raw
          field meta, :"raw_#{io}"
        else
          fail ArgumentError, "Unknown args for key: #{args.inspect}"
        end
      else
        tname = table_name(meta, args.first)
        k     = args.last
        "#{tname}.#{k}"
      end

    when 1, 3
      tname = meta[:name]
      k     = args.first
      case k
      when :raw_in
        "#{tname}.#{fields[:in]}"
      when :raw_out
        "#{tname}.#{fields[:out]}"
      when :type_id
        "#{tname}.#{k}"
      else
        if meta.has_key? k
          "#{tname}.#{meta[k]}"
        else
          puts meta.inspect
          "unknown"
        end
      end

    else
      fail ArgumentError, "Unknown args: #{args.inspect}"

    end # === case
  end

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

      @WITH = if @WITHS.empty?
                ""
              else
                withs = @WITHS.compact.uniq
                withs = (withs + withs.map { |k| self[k].to_meta[:WITHS] }).
                  flatten.
                  compact.
                  uniq
                str = withs.map { |k| "#{k} AS ( #{self[k].FRAGMENT} )" }.join ",\n  "
                %{WITH\n  #{str}\n}
              end
      @SQL = [@WITH, @FRAGMENT].compact.join NEW_LINE
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
  end # === fragments_to_raw

  def compile_meta
    aputs @data
    fail "NOT rEADY"

    k = nil
    case k

    when :name

    when :select
      sql[:SELECT].concat(meta[:select] || ['*'])

    when :of
      sql[:WHERE] << %^#{meta[:from].first}.owner_id = #{meta[:of].inspect}^

    when :where

      sql[:WHERE].concat meta[:where]

      sql[:WHERE] << "#{field meta, :type_id} = :#{meta[:name].to_s.upcase}_TYPE_ID"

      if meta[:not_exists]
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



