
# TODO:
#
#   -- Add .WHERE("string", :'=', i_dig_sql)
#   -- Add .WHERE("string", :'=', rec)
#   -- Add .WHERE("string = ? ", rec)
#   -- Add .WHERE("string = ? ", i_dig_sql)
#
#
class I_Dig_Sql

  class << self
  end # === class self ===

  def initialize sql = nil, args = nil
    @withs   = []
    @select  = nil
    @as      = nil
    @unions  = []
    @sql     = sql
    @args    = args || []
    yield self if block_given?
  end

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
    @args.concat args
    self
  end

  alias_method :comma, :WITH

  def SELECT str, *args
    @select = {:select=>str, :args=>args, :from=>nil, :where=>nil}

    self
  end

  def FROM o
    @select[:from] = o

    self
  end

  def WHERE o, *args
    @select[:where] = o
    @args.concat args
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



