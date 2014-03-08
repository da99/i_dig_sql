
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

  def WITH o
    @withs << o

    self
  end

  def SELECT str, *args
    @select = {:select=>str, :args=>args, :from=>nil, :where=>nil}

    self
  end

  def FROM o
    @select[:from] = o

    self
  end

  def WHERE o
    @select[:where] = o

    self
  end

  def UNION o
    @unions << o

    self
  end

  def to_sql

    if @sql
      s = @sql
    else

      s = ""
      unless @withs.empty?
        s << "\n  WITH"
        s << @withs.map { |w|
          " #{w.AS} AS (#{w.to_sql[:sql]}) "
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
      s << "\nUNION  #{@unions.map { |sql| sql.to_sql[:sql] }.join "\nUNION\n" }"
    end

    s << "\n"

    {:sql=>s, :args=>[]}
  end

end # === class I_Dig_Sql ===

sn = I_Dig_Sql.new
sn.SELECT(' ? AS parent_id ', 22)
.FROM(' screen_name ')

mag = I_Dig_Sql.new
mag.SELECT(' ? AS parent_id ', 23)
.FROM(' magazine ')

sql = I_Dig_Sql.new
puts sql
.WITH(sn.AS('sn_parent'))
.WITH(mag.AS('mag_parent'))
.WITH(
  I_Dig_Sql.new('SELECT * FROM mag_parent')
  .UNION(
    I_Dig_Sql.new('SELECT * FROM sn_parent')
  )
  .AS('parent_tree')
)
.SELECT(" ? AS parent_id ", 11)
.FROM("the_tree")
.WHERE(" id > 0")
.to_sql[:sql]




