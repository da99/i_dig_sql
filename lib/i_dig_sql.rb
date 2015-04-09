
class I_Dig_Sql

  include Enumerable
  HAS_VAR = /(\{\{|\<\<)[^\}\>]+(\}\}|\>\>)/

  Duplicate = Class.new RuntimeError

  class << self
  end # === class self ===

  class H < Hash

    def initialize *options
      @h_option = {}
      options.each { |name|
        case name
        when :allow_update
          @h_option[:allow_update] = true
        else
          fail ArgumentError, "Unknown option: #{name.inspect}"
        end
      }

      super()
    end

    def [] name
      fail ArgumentError, "Unknown key: #{name.inspect}" unless has_key?(name)
      super
    end

    def []= name, val
      if has_key?(name) && self[name] != val && !@h_option[:allow_update]
        fail ArgumentError, "Key already set: #{name.inspect}"
      end

      super
    end

    def merge_these *args
      args.each { |h|
        h.each { |k,v|
          self[k] = v
        }
      }
      self
    end

  end # === class H

  attr_reader :sqls, :vars
  def initialize *args
    @digs = args.select { |a|
      a.is_a? I_Dig_Sql
    }

    @sqls   = H.new
    @vars   = H.new
    @fields = H.new

    @current_def  = nil

    @sqls.merge_these *(@digs.map(&:sqls))
    @vars.merge_these *(@digs.map(&:vars))

    @fragments = (
      args
      .select { |s| s.is_a? String }
    )
  end

  def fields h = nil
    return @fields unless h
    @fields.merge! h
  end

  def [] name
    @sqls[name]
  end

  def []= name, val
    @sqls[name] = val
  end

  def each
    if block_given?
      @sqls.each { |k, v| yield k, v }
    else
      @sqls.each
    end
  end

  # === LINK DSL ====================================================
  def def name
    @sqls[name] = H.new(:allow_update).merge!(
      :name       => name,
      :order_by   => [],
      :group_by   => [],
      :select     => [],
      :where      => [],
      :from       => [],
      :type_ids   => [],
      :out        => nil,
      :in         => nil,
      :out_ftable => nil,
      :in_ftable  => nil,
      :out_has    => nil,
      :in_has     => nil,
      :not_exists => nil
    )
    old = @current_def
    @current_def = @sqls[name]
    instance_eval &Proc.new
    @current_def = old
    self
  end

  def out_in o, i
    @current_def[:out] = o
    @current_def[:in]  = i
    @out_in ||=[]
    @out_in << :out
    @out_in << :in
    instance_eval(&Proc.new) if block_given?
    @out_in.pop
    @out_in.pop
    self
  end

  def are table_name
    @current_def[:out_ftable] = table_name
    @current_def[:in_ftable]  = table_name
    self
  end

  def have table_name
    @current_def[:out_has] = table_name
    @current_def[:in_has]  = table_name
    self
  end

  def not_exists t
    if (@out_in.size % 2) != 0
      fail ArgumentError, "Currently, :not_exists can only be used within: out_in { }."
    end
    @current_def[:not_exists] = t
    self
  end

  def order_by *args
    @current_def[:order_by] << args
    self
  end

  def group_by *args
    @current_def[:group_by] << args
    self
  end

  def select *args
    @current_def[:select] << args
    self
  end

  def get *args
    @current_def[:from].concat args
    self
  end

  def of name
    @current_def[:of] = name
  end

  ALL_UNDERSCORE = /\A[_]+\Z/
  COMBO_LEFT_RIGHT = [:left, :left, :right, :right]
  COMBO_OUT_IN     = [:out, :in, :out, :in]
  def where str
    _and_ = []
    lines = str.strip.split("\n")
    _and_ << lines.shift
    lines.map { |line|
      line.split.each_with_index { |k, i|
        next if k[ALL_UNDERSCORE]
        _and_ << [COMBO_LEFT_RIGHT[i], COMBO_OUT_IN[i], k.to_sym]
      }
    }
    @current_def[:where] << _and_
    self
  end
  alias_method :or, :where
  # =================================================================

  # === Rendering DSL ===============================================

  def << str
    @fragments << str
  end

  def to_pair
    [to_sql, vars]
  end

  def to_sql target_name = nil
    final = {
      WITH:     [],
      RAW:      [],
      WITH!:    nil
    }

    fail ArgumentError, "No query defined." if !target_name && @fragments.empty?

    fragments_to_raw(@fragments, final)
    table_name_to_raw(target_name, final) if target_name
    with_to_raw(final)

    string = ""

    if !final[:WITH!].empty?
      string << (%^WITH\n  #{final[:WITH!].join ",\n  "}\n^)
    end

    string << (final[:RAW].join "\n")

    string
  end # === def to_sql

  private # ==========================================

  def prefix_raw sym
    "raw_#{sym.to_s.split('_').first}".to_sym
  end

  def prefix sym
    sym.to_s.split('_').first.to_sym
  end

  def table_name meta, k
    name = meta[:name]
    case k
    when :out_ftable, :in_ftable
      "#{name}_#{ meta[prefix(k)] }_#{meta[k]}"
    else
      fail ArgumentError, "Unknown key for table name: #{k.inspect}"
    end
  end

  #
  # Example:
  #   field meta, :in, :owner_id
  #   field meta, :screen_name, :screen_name
  #   field meta, :in
  #   field meta, :raw_in
  def field meta, *args
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

  def fragments_to_raw str_or_arr, final = {:WITH=>[], :RAW=>[]}
    raws = if str_or_arr.is_a?(String)
             [str_or_arr]
           else
             str_or_arr
           end

    fragments = raws.dup
    while s = fragments.shift
      next unless s.is_a?(String)

      final[:RAW] << s
      while s[HAS_VAR] 
        s.gsub!(/\{\{\s?([a-zA-Z0-9\_]+)\s?\}\}/) do |match|
          key = $1.to_sym
          final[:WITH] << key
          key
        end

        s.gsub!(/\<\<\s?([a-zA-Z0-9\_\-\ \*]+)\s?\>\>/) do |match|
          tokens = $1.split
          key    = tokens.pop.to_sym
          field  = tokens.empty? ? nil : tokens.join(' ')

          case
          when field
            final[:WITH] << key
            "SELECT #{field} FROM #{key}"
          else
            self[key]
          end
        end
      end # === while s HAS_VAR

    end # === while

    final
  end # === fragments_to_raw

  def table_name_to_raw key, final
    target = self[key]

    if target.is_a?(String)
      fragments_to_raw([target], final)
      return
    end

    final[:RAW] << "-- i_dig_sql: #{key.inspect}"
    final[:RAW] << meta_to_fragment(target, final)
  end

  def meta_to_fragment meta, final
    sql = {
      :SELECT   => [],
      :FROM     => [],
      :WHERE    => [],
      :ORDER_BY => [],
      :GROUP_BY => []
    }

    [
      :of,
      :name,

      :order_by,
      :group_by,
      :from,
      :select,
      :where
    ].each { |k|
      case k

      when :name

      when :select
        sql[:SELECT].concat(meta[:select] || ['*'])

      when :of
        next unless meta.has_key?(:of)
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
    }

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
  end # === def cte_to_string

  def with_to_raw final
    withs    = final[:WITH].dup
    used     = []
    compiled = []

    while k = withs.shift
      next if used.include?(k)

      size = withs.size
      case k
      when Symbol
        meta = self[k]
        if meta.is_a?(String)
          compiled << "#{k} AS ( #{meta} )"
        else
          withs.unshift meta
        end

      when Hash
        compiled << "#{k[:name]} AS (#{meta_to_fragment(k, final)})"

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



