
describe :to_pair do

  it "returns an Array: [String, Hash]" do
    i = I_Dig_Sql.new <<-EOF
      SELECT * FROM new
    EOF
    i.vars[:one] = 2
    sql, vars = i.to_pair
    sql(sql).should == sql("SELECT * FROM new")
    vars.should == {one: 2}
  end # === it

end # === describe :to_pair

