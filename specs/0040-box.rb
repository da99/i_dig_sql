
describe ":box" do

  it "turns a box into a String" do
    sql = I_Dig_Sql.new
    sql.box :joins do

      from(:n) {
        as :notes
        field :long_name, :name
      }

      left(:f) {
        as :fails
        on '_.n = __.n'
        field :long_name, :name
      }

    end

    sql[:joins].data[:raw].should == %^
      SELECT
        notes.long_name AS name,
        fails.long_name AS name
      FROM
        n notes
        LEFT JOIN f fails
        ON fails.n = notes.n
    ^
  end # === it

end # === describe ":box"
