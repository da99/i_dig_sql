
describe ":to_hash" do

  it "creates a hash when content is on the same line: SELECT ... \\n" do
    h = I_Dig_Sql.to_hash "SELECT key_name\nFROM table"
    h.should == {'SELECT'=>['key_name'], 'FROM'=>['table']}
  end # === it

  it "creates a hash when content is below it: SELECT\\n...\\n..." do
    h = I_Dig_Sql.to_hash "
      SELECT
        key_name,
        another_key
      FROM
        t1, t2
     "
    h.should == {'SELECT'=>['key_name,', 'another_key'], 'FROM'=>['t1, t2']}
  end # === it

end # === describe ":to_hash"
