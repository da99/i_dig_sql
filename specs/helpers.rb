

require "Bacon_Colored"

def sql o
  if o.is_a? String
    return o.split.join(" ")
  else
    sql(o.to_sql)
  end
end


