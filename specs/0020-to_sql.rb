

describe :to_sql do

  it "renders nested replacements"  do
    i = I_Dig_Sql.new <<-EOF
      << FIRST >>
    EOF
    i[:FIRST] = " << SECOND >> "
    i[:SECOND] = " << THIRD >> "
    i[:THIRD] = "SELECT id FROM phantom"
    sql(i).should == "SELECT id FROM phantom"
  end # === it

  it "prints CTE definitions once, if used multiple times" do
    i = I_Dig_Sql.new <<-EOF
      {{my_cte}}
      {{my_cte}}
    EOF
    i[:my_cte] = "SELECT * FROM my"
    sql(i).should == sql(%^
      WITH
      my_cte AS (
        SELECT * FROM my
      )
      my_cte
      my_cte
    ^)
  end # === it

end # === describe :to_sql
