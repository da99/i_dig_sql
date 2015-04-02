
class I_Dig_Sql


  class << self
  end # === class self ===

  attr_reader :sql
  def initialize *args
    @digs = args.select { |a| a.is_a? I_Dig_Sql }
    @digs << self
    @digs = @digs.reverse

    @sql  = {}
    @sql.default_proc = lambda { |h, k|
      fail ArgumentError, "Unknown key: #{k.inspect}"
    }

    @vars = {}
    @vars.default_proc = lambda { |h, k|
      fail ArgumentError, "Unknown key: #{k.inspect}"
    }

    @string = ""
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

  def var *args
    case args.size
    when 1
      @vars[name]
    when 2
      name, v = args
      if @vars.has_key?(name) && @vars[name] != v
        fail ArgumentError, "VAR already defined: #{name.inspect}"
      end
      @vars[name] = v
    else
      fail ArgumentError, "Unknown args: #{args.inspect}"
    end
  end

  def [] name
    found = false
    var   = nil
    @digs.detect { |f|
      if f.sql.has_key?(name)
        var = f.sql[name]
        found = true
      end
      found
    }

    return var if found
    fail ArgumentError, "SQL not found: #{name.inspect}"
  end

  def []= name, val
    if @sql.has_key?(name) && @sql[name] != val
      fail ArgumentError, "SQL already set: #{name.inspect}"
    end

    @sql[name] = val
  end

  def to_sql
    s    = @string.dup
    ctes = []

    s.gsub!(/\{\{\{\s?([a-zA-Z0-9\_]+)\s?\}\}\}/) do |match|
      key = $1.to_sym
      self[key]
    end

    s.gsub!(/\{\{\s?\*\s?([a-zA-Z0-9\_]+)\s?\}\}/) do |match|
      key = $1.to_sym
      ctes << key

      # --- check to see if key exists.
      # Uses :default_proc if missing.
      self[key.to_sym]

      "SELECT * FROM #{key}"
    end

    s.gsub!(/\{\{\s?([a-zA-Z0-9\_]+)\s?\}\}/) do |match|
      key = $1.to_sym
      ctes << key
      key
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



