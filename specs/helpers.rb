

require "Bacon_Colored"
require "awesome_print"

module Kernel
  def aputs *args
    ap *args, :indent=>-2
  end
end

def sql o
  if o.is_a? String
    return o.split.join(" ")
  else
    sql(o.to_sql)
  end
end


