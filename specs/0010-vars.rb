
describe :vars do

  it "combines vars from other digs" do
    one   = I_Dig_Sql.new
    one.vars[:one] = 1

    two   = I_Dig_Sql.new
    one.vars[:two] = 2

    three = I_Dig_Sql.new
    one.vars[:three] = 3

    dig = I_Dig_Sql.new one, two, three
    dig.vars[:four] = 4

    dig.vars.should == {
      four:  4,
      three: 3,
      two:   2,
      one:   1
    }
  end # === it

  it "fails w/Duplicate if other digs have the same var name" do
    should.raise(ArgumentError) {
      one = I_Dig_Sql.new
      one.vars[:two] = 2

      i = I_Dig_Sql.new one
      i.vars[:two] = 3
      i.vars
    }.message.should.match /Key already set: :two/
  end # === it

end # === describe :vars


