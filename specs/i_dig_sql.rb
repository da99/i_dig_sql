
require "i_dig_sql"
require "i_dig_sql/String"

def sql o
  if o.is_a? String
    return o.split.join(" ")
  else
    sql(o.to_sql[:sql])
  end
end

describe ".new" do

  it "returns a I_Dig_Sql if passed a String" do
    o = I_Dig_Sql.new("SELECT * FROM some_table")
    o.class.should == I_Dig_Sql
  end

end # === describe it runs ===

describe "#WITH()" do

  it "includes passed String" do
    o = I_Dig_Sql.new
    o.WITH("some_table AS (SELECT * FROM other_table)")
    sql(o).should == sql("WITH some_table AS (SELECT * FROM other_table)")
  end

end # === describe #WITH() ===

describe "#to_sql" do

  it "includes both WITH and SELECT statements" do
    o = I_Dig_Sql.new
    o.WITH("cte AS (SELECT * FROM other_table)")
    o.SELECT(" parent_id ")
    .FROM("main_table")
    sql(o).should == sql(%^
                         WITH cte AS (SELECT * FROM other_table)
                         SELECT parent_id
                         FROM main_table
                         ^)
  end

end # === describe #to_sql ===


