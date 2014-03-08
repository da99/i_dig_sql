
class I_Dig_Sql

  class << self
  end # === class self ===

  def initialize
    @withs   = []
    @select  = nil
    @as      = nil
  end

  def AS o = :return
    return @as if o == :return

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

  def to_sql
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

    s << "\n"

    {:sql=>s, :args=>[]}
  end

end # === class I_Dig_Sql ===

sn = I_Dig_Sql.new
sn.SELECT(' ? AS parent_id ', 22)
.FROM(' screen_name ')

sql = I_Dig_Sql.new
puts sql
.WITH(sn.AS('the_screen_names'))
.SELECT(" ? AS parent_id ", 11)
.FROM("table_name")
.WHERE(" id > 0")
.to_sql[:sql]




