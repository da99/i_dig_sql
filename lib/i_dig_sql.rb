
class I_Dig_Sql

  include Enumerable

  Duplicate = Class.new RuntimeError

  class << self
  end # === class self ===

  class H < Hash

    def [] name
      fail ArgumentError, "Unknown key: #{k.inspect}" unless has_key?(name)
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

    s.gsub!(/\{\{\s?(\!|\*)?\s?([a-zA-Z0-9\_]+)\s?\}\}/) do |match|
      key = $2.to_sym
      case $1
      when "!"
        self[key]
      when "*"
        ctes << key
        "SELECT * FROM #{key}"
      else
        ctes << key
        key
      end
    end

    return s if ctes.empty?

    %^
      WITH
      #{ctes.map { |k| "#{k} AS (
        #{self[k]}
      )" }.join "
      ,
      "}
      #{s}
    ^
  end

end # === class I_Dig_Sql ===



