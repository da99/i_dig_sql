

describe :to_sql do

  it "renders nested replacements"  do
    i = I_Dig_Sql.new <<-EOF
      << FIRST >>
    EOF
    i[:FIRST] = " << SECOND >> "
    i[:SECOND] = " << THIRD >> "
    i[:THIRD] = "FINAL"
    sql(i).should == "FINAL"
  end # === it

  it "prints CTE definitions once, if used multiple times" do
    i = I_Dig_Sql.new <<-EOF
      {{my_cte}}
      {{my_cte}}
    EOF
    i[:my_cte] = "SELECT *"
    sql(i).should == sql(%^
      WITH
      my_cte AS (
        SELECT *
      )
      my_cte
      my_cte
    ^)
  end # === it

end # === describe :to_sql
