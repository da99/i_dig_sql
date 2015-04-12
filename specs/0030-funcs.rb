
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

  it "allows ? and ! in the name" do
    sql = I_Dig_Sql.new :q, <<-EOF
      << name! Hans >>
      << name? Hoppe >>
    EOF
    sql[:name!] = lambda { |dig, arg| "not! #{arg}" }
    sql[:name?] = lambda { |dig, arg| "is? #{arg}" }
    sql(sql).should == sql(%^
      not! Hans
      is? Hoppe
    ^)
  end # === it

  it "passes Symbols to the lambda" do
    sql = I_Dig_Sql.new :q, <<-EOF
      << name! Hans >>
    EOF
    sql[:name!] = lambda { |dig, arg| "#{arg.class}" }
    sql(sql).should == sql(%^
       Symbol
    ^)
  end # === it

  it "ignores colons among arguments" do
    sql = I_Dig_Sql.new :q, <<-EOF
      << names :Hans, :Hoppe >>
    EOF
    sql[:names] = lambda { |dig, *args| "#{args.join " -- "}" }
    sql(sql).should == sql(%^
       Hans -- Hoppe
    ^)
  end # === it

  it "ignores commas among arguments" do
    sql = I_Dig_Sql.new :q, <<-EOF
      << names Hans, Hoppe >>
    EOF
    sql[:names] = lambda { |dig, *args| "#{args.join " - "}" }
    sql(sql).should == sql(%^
       Hans - Hoppe
    ^)
  end # === it

end # === describe :funcs
