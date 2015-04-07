
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

    @sqls.merge_these *(@digs.map(&:sqls))
    @vars.merge_these *(@digs.map(&:vars))

    @string = args.select { |s| s.is_a? String }.join("\n")
    @current_def = nil
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
    @string << (
      if @string.empty?
        str
      else
        "\n" << str
      end
    )
  end

  def to_pair
    [to_sql, vars]
  end

  def to_sql
    s    = @string.dup
    ctes = []

    while s[HAS_VAR]
      s.gsub!(/\{\{\s?([a-zA-Z0-9\_]+)\s?\}\}/) do |match|
        key = $1.to_sym
        ctes << key
        key
      end

      s.gsub!(/\<\<\s?([a-zA-Z0-9\_\-\ \*]+)\s?\>\>/) do |match|
        tokens = $1.split
        key    = tokens.pop.to_sym
        field  = tokens.empty? ? nil : tokens.join(' ')

        case
        when field
          ctes << key
          "SELECT #{field} FROM #{key}"
        else
          self[key]
        end
      end
    end

    return s if ctes.empty?

    %^
      WITH
      #{ctes.uniq.map { |k| "#{k} AS (
        #{self[k]}
      )" }.join "
      ,
      "}
      #{s}
    ^
  end # === def to_sql

  # === LINK DSL ====================================================
  def def name
    @sqls[name] = {:name=>name}
    old = @current_def
    @current_def= @sqls[name]
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
    @current_def[:order_by] ||= []
    @current_def[:order_by] << args
    self
  end

  def group_by *args
    @current_def[:group_by] ||= []
    @current_def[:group_by] << args
    self
  end

  def select *args
    @current_def[:select] ||= []
    @current_def[:select] << args
    self
  end

  def get *args
    @current_def[:from] ||= []
    @current_def[:from] << args
    self
  end

  def of name
    @current_def[:start] = name
  end

  def type_id name
    old = @current_def
    old[:type_ids] ||= []
    old[:type_ids] << {}
    @current_def = old[:type_ids].last
    instance_eval(&Proc.new) if block_given?
    @current_def = old
    self
  end
  # =================================================================

end # === class I_Dig_Sql ===



