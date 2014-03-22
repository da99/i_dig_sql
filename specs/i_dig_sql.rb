
require "i_dig_sql"
require "i_dig_sql/String"

def sql o
  if o.is_a? String
    return o.split.join(" ")
  else
    sql(o.to_sql[:sql])
  end
end

def args o
  o.to_sql[:args]
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

  it "accepts another I_Dig_Sql object" do
    other = I_Dig_Sql.new("SELECT * FROM main_table")
    .AS('cte1')

    o = I_Dig_Sql.new
    .WITH(other)
    sql(o).should == sql(%^
      WITH cte1 AS ( SELECT * FROM main_table )
    ^)
  end

  it "accepts args" do
    o = I_Dig_Sql.new
    .WITH(" some_table AS (SELECT * FROM other_table WHERE id = ?) ", 1)
    args(o).should == [1]
  end

  it "merges args from other I_Dig_Sql objects" do
    other = I_Dig_Sql.new("SELECT * FROM main_table WHERE i = ?", 1).AS('cte1')

    o = I_Dig_Sql.new
    .WITH(other)
    args(o).should == [1]  end

end # === describe #WITH() ===

describe "#comma" do

  it "acts like a WITH statement" do
    o = I_Dig_Sql.new
    .WITH('cte1 AS ( SELECT * FROM table_1 ) ')
    .comma('cte2 AS ( SELECT * FROM table_2 )')

    sql(o).should == sql(%^
                         WITH
                           cte1 AS ( SELECT * FROM table_1 )
                         , cte2 AS ( SELECT * FROM table_2 )
                         ^)
  end

  it "saves args" do
    o = I_Dig_Sql.new
    .WITH('cte1 AS ( SELECT * FROM table_1 ) ')
    .comma('cte2 AS ( SELECT * FROM table_2 WHERE id = ?)', 2)

    args(o).should == [2]
  end

end # === describe #comma ===

describe "#to_sql" do

  describe ":sql" do

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

  end # === describe :sql ===

  describe ":args" do

    it "returns an array of arguments" do
      o = I_Dig_Sql.new
      .SELECT(" parent_id ")
      .FROM("main_table")
      .WHERE(" ? = ? AND b = ? ", 1, 2, 3)
      args(o).should == [1,2,3]
    end

  end # === describe :args ===
  

end # === describe #to_sql ===

describe "#WHERE" do

  it "merges sql into string if arg is a I_Dig_Sql" do
    other = I_Dig_Sql.new.SELECT("*").FROM("other")

    o = I_Dig_Sql.new.SELECT("parent_id")
    .FROM("main")
    .WHERE("id IN", other)

    sql(o).should == sql(%~
      SELECT parent_id
      FROM main
      WHERE id IN (
        SELECT * FROM other
      )
    ~)
  end

  it "merges args if arg is a I_Dig_Sql" do
    other = I_Dig_Sql.new.SELECT("*").FROM("other")
    .WHERE("id = ", 1)

    o = I_Dig_Sql.new.SELECT("parent_id")
    .FROM("main")
    .WHERE("id IN", other)

    args(o).should == [1]
  end

  it "raises exception if used more than once" do
    lambda {
      I_Dig_Sql.new
      .SELECT('*')
      .FROM('main')
      .WHERE("id = 1")
      .WHERE("id = 2")
    }.should.raise(I_Dig_Sql::Only_One_Where)
    .message.should.match(/Multiple use of WHERE:/)
  end

end # === describe #WHERE ===


describe "String#i_dig_sql" do

  it "returns an I_Dig_Sql instance set to String" do
    o = "SELECT id FROM my_table".i_dig_sql
    sql(o.to_sql[:sql]).should == sql(%^SELECT id FROM my_table^)
  end

end # === describe String ===

