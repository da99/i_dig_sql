

describe '.new' do

  it "merges sql values: .new(i_dig_sql)" do
    first = I_Dig_Sql.new
    first[:hero] = "SELECT * FROM hero"
    second = I_Dig_Sql.new(first)
    second[:name] = "SELECT * FROM name"
    second << %^
      << hero >>
      << name >>
    ^
    sql(second).should == sql(%^
      SELECT * FROM hero
      SELECT * FROM name
    ^)
  end # === it

end # === describe '.new'
