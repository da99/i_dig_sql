
describe ":box" do

  it "turns a box into a String" do
    sql = I_Dig_Sql.new
    sql.box :joins do

      from(:n) {
        as :notes
        select :long_name, :name
      }

      left(:f) {
        as :fails
        on '_.n = __.n'
        select :long_name, :name
      }

    end

    sql(sql[:joins].SQL).should == sql(%^
      SELECT
        notes.long_name AS name,
        fails.long_name AS name
      FROM
        n notes
        LEFT JOIN f fails
        ON fails.n = notes.n
    ^)
  end # === it

end # === describe ":box"
