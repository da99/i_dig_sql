
describe :funcs do

  it "let's you use a lambda in a SQL fragment" do
    sql = I_Dig_Sql.new :q, <<-EOF
      SELECT name
      FROM screen_name
      WHERE
        << id >>
    EOF

    sql[:id] = lambda { |dig| "id = :id" }

    sql(sql).should == sql(%^
      SELECT name
      FROM screen_name
      WHERE
        id = :id
    ^)
  end # === it

  it "passes args to function" do
    sql = I_Dig_Sql.new :q, <<-EOF
      SELECT name
      FROM screen_name
      WHERE
        << names Hans Hoppe >>
    EOF

    sql[:names] =  lambda { |dig, *args| "name IN [#{args.join ', '}]" }

    sql(sql).should == sql(%^
      SELECT name
      FROM screen_name
      WHERE
        name IN [Hans, Hoppe]
    ^)
  end # === it

end # === describe :funcs
