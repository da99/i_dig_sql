
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
    h.should == {'SELECT'=>['key_name', 'another_key'], 'FROM'=>['t1, t2']}
  end # === it

  it "replaces underscores when: t1 \\n INNER JOIN t2" do
    h = I_Dig_Sql.to_hash <<-EOF
      SELECT
        key_name
      FROM
        t1
        INNER JOIN t2
          ON _.owner_id == __.id
    EOF
    h.should == {
      'SELECT' => ['key_name'],
      'FROM'   => ['t1', 'INNER JOIN t2', 'ON t2.owner_id == t1.id']
    }
  end # === it

  it "replaces underscores when: t1 AS table_1 INNER JOIN t2 AS table_2" do
    h = I_Dig_Sql.to_hash <<-EOF
      SELECT
        key_name
      FROM
        t1 AS table_1 INNER JOIN t2 AS table_2
          ON _.owner_id == __.id
    EOF
    h.should == {
      'SELECT' => ['key_name'],
      'FROM'   => ['t1 AS table_1 INNER JOIN t2 AS table_2', 'ON table_2.owner_id == table_1.id']
    }
  end # === it

end # === describe ":to_hash"
