
class I_Dig_Sql

  include Enumerable
  HAS_VAR = /(\{\{|\<\<)[^\}\>]+(\}\}|\>\>)/

  Duplicate = Class.new RuntimeError

  class << self
  end # === class self ===

  class H < Hash

    def [] name
      fail ArgumentError, "Unknown key: #{name.inspect}" unless has_key?(name)
      super
    end

    def []= name, val
      if has_key?(name) && self[name] != val
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

    @sqls = H.new
    @vars = H.new

    @current_def  = nil

    @sqls.merge_these *(@digs.map(&:sqls))
    @vars.merge_these *(@digs.map(&:vars))

    @fragments = (
      args
      .select { |s| s.is_a? String }
    )
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

  # === LINK DSL ====================================================
  def def name
    @sqls[name] = H.new.merge!(
      :name       => name,
      :order_by   => [],
      :group_by   => [],
      :select     => [],
      :from       => [],
      :type_ids   => []
      # :out        => nil,
      # :in         => nil,
      # :out_ftable => nil,
      # :in_ftable  => nil,
      # :out_has    => nil,
      # :in_has     => nil,
      # :in_not_in  => nil,
      # :out_not_in => nil
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

  def not_in t
    @out_in.each { |k|
      @current_def["#{k}_not_in".to_sym] = t
    }
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

  def type_id name
    old = @current_def
    old[:type_ids] << {}
    @current_def = old[:type_ids].last
    instance_eval(&Proc.new) if block_given?
    @current_def = old
    self
  end
  # =================================================================

  # === Rendering DSL ===============================================

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

    final[:RAW] << "-- i_dig_sql: #{key.inspect}\n"
    w, s = meta_to_WITH_and_String(target, final)
    final[:WITH].concat w
    final[:RAW] << s
  end

  def meta_to_WITH_and_String meta, final

    [
      :name,

      :order_by,
      :group_by,
      :from,
      :select,

      :in,
      :of
    ].each { |k|
      case k

      when :name

      when :select
        final[:SELECT].concat(meta[:select] || ['*'])

      when :from
        final[:WITH].concat meta[:from]
        final[:FROM].concat meta[:from]

      when :of
        next unless meta.has_key?(:of)
        final[:WHERE] << %^#{meta[:from].first}.owner_id = #{meta[:of].inspect}^

      when :order_by

      when :group_by
        final[:GROUP_BY].concat meta[:group_by]

      when :in
        next unless meta.has_key?(:in)
        final[:RAW] <<(
          meta.map { |k,v|
            "#{k}: #{v.inspect}"
          }.join ",\n    "
        )

      else
        fail "Programmer Error: unknown key #{k.inspect}"

      end # === each
    }

    return [[],meta.keys.inspect]
  end # === def cte_to_string

  def with_to_raw final
    withs    = final[:WITH].dup
    used     = []
    compiled = []

    while k = withs.shift
      next if used.include?(k)

      case k
      when Symbol
        meta = self[k]
        if meta.is_a?(String)
          compiled << "#{k} AS ( #{meta} )"
        else
          withs.unshift meta
        end

      when Hash
        k

      else
        fail ArgumentError, "Unknown type for :WITH: #{k.class}"
      end
      used << k
    end # === while

    final[:WITH!] = compiled

  end # === def with_to_raw

  def hash_to_with_and_string h
    final = {
      WITH:     [],
      SELECT:   [],
      FROM:     [],
      FROM_AS:  H.new,
      WHERE:    [],
      WHERE_AS: H.new,
      GROUP_BY: [],
      HAVING:   [],
      LIMIT:    [],
      OFFSET:   [],
      RAW:      []
    }
    string = clauses.map { |name|

      next if final[name] && final[name].empty?

      case name

      when :SELECT
        %^SELECT\n  #{final[name].flatten.join ",\n  "}\n^

      when :FROM
        joins = []
        final[name].each_with_index { |v, i|
          joins << case i
          when 0
            v
          else
            " INNER JOIN #{v}\n    ON some.id = other.id "
          end
        }
        %^FROM\n  #{joins.join "\n "}\n^

      when :WHERE
        %^WHERE\n  #{final[name].join ",\n  "}\n^

      when :GROUP_BY
        %^GROUP BY\n #{final[name].join ",\n  "}^

      when :HAVING

      when :LIMIT

      when :OFFSET

      else
        fail "Programmer error: Not dealt: #{name.inspect}"

      end # === case
    }.flatten.compact.join "\n".freeze
  end # === def hash_to_with_and_string

  # === END: Rendering DSL ==========================================

end # === class I_Dig_Sql ===



