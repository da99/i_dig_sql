
describe :[] do

  it "fails if referencing a value that doesn't exist" do
    i = I_Dig_Sql.new :poll, %^
      SELECT * FROM {{all_the_polls}}
    ^
    should.raise(ArgumentError) {
      i.to_sql
    }.message.should.match /not found: .all_the_polls/i
  end # === it

end # === describe :[]
