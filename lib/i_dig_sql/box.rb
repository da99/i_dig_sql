
require "boxomojo"

class I_Dig_Sql

  Box = Boxomojo.new(:from, :left, :right, :inner, :as, :field, :collect=>[:on])

  class << self

    def box_to_string box
      "not done"
    end # === def box_to_string

  end # === class << self

  def box name
    boxes = Box.new(&Proc.new)
    self[name] = boxes
  end # === def box name

end # === I_Dig_Sql
