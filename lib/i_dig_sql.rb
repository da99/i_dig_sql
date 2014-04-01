
class I_Dig_Sql

  Only_One_Where = Class.new(RuntimeError)

  class << self
  end # === class self ===

  def initialize sql = nil, *args
    @withs   = []
    @tags_for_withs = {}
    @select  = nil
    @as      = nil
    @unions  = []
    @sql     = sql
    @args    = args
    yield self if block_given?
  end

  def args
    @args
  end
  protected :args

  def AS o = :return
    if o == :return
      return @as if @as
      raise "@as not set"
    end

    @as = o
    self
  end

  def WITH o, *args
    @withs << o
    @tags_for_withs[o] = []
    @args.concat(o.args) if o.is_a?(I_Dig_Sql)
    @args.concat args
    self
  end

  alias_method :comma, :WITH

  def tag_as name
    list = @tags_for_withs[@withs.last]
    raise "Last query was not a WITH/cte query" unless list
    list.push name
    self
  end

  def find_tagged name
    @tags_for_withs.inject([]) { |memo, (k,v)|
      if v.include?(name)
        memo << k
      end
      memo
    }
  end

  def SELECT str, *args
    @select = {:select=>str, :args=>args, :from=>nil, :where=>nil}

    self
  end

  def FROM o
    @select[:from] = o

    self
  end

  def WHERE o, *args

    if @select[:where]
      raise Only_One_Where.new("Multiple use of WHERE: #{@select[:where]} |--| #{o}")
    end

    if args.size == 1 && args.first.is_a?(I_Dig_Sql)
      sql = args.first.to_sql
      o = "#{o} ( #{sql[:sql]} )"
      @args.concat sql[:args]
    else
      @args.concat args
    end

    @select[:where] = o
    self
  end

  def UNION o
    @unions << o

    self
  end

  def to_sql

    if @sql
      s = "\n  "
      s << @sql
    else

      s = ""
      unless @withs.empty?
        s << "\n  WITH"
        s << @withs.map { |w|
          case w
          when String
            " #{w} "
          else
            " #{w.AS} AS (#{w.to_sql[:sql]}) "
          end
        }.join("\n,\n")
      end

      s << "\n"

      if @select
        s << "\n  SELECT #{@select[:select]}"
        s << "\n  FROM   #{@select[:from]}"   if @select[:from]
        s << "\n  WHERE  #{@select[:where]}"  if @select[:where]
      end

    end # === if @sql

    if not @unions.empty?
      s << "\n  UNION  #{@unions.map { |sql| sql.to_sql[:sql] }.join "\nUNION\n" }"
    end

    s << "\n"

    {:sql=>s, :args=>@args}
  end

end # === class I_Dig_Sql ===



