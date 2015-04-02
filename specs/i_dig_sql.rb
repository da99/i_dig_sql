
require "Bacon_Colored"

def sql o
  if o.is_a? String
    return o.split.join(" ")
  else
    sql(o.to_sql)
  end
end

def args o
  o.to_sql[:args]
end

describe :I_Dig_Sql do

  it "runs the code from README.md" do
    readme = File.read(File.expand_path(File.dirname(__FILE__) + '/../README.md'))
    code   = readme[/```ruby([^`]+)```/] && $1
    line   = 0
    readme.split("\n").detect { |l| line = line + 1; l['```ruby'] }
    result = eval(code, nil, 'README.md', line)
    sql(result)['WITH HEROES'].should == 'WITH HEROES'
  end # === it

  it "adds WITH: {{MY_NAME}}" do
    sql = I_Dig_Sql.new
    sql[:MY_HERO] = "SELECT * FROM hero"
    sql[:MY_NAME] = "SELECT * FROM name"
    sql << %^
      {{MY_HERO}}
      {{MY_NAME}}
    ^
    sql(sql).should == sql(%^
      WITH 
      MY_HERO AS (
        SELECT * FROM hero
      )
      ,
      MY_NAME AS (
        SELECT * FROM name
      )
      MY_HERO
      MY_NAME
    ^)
  end

  it "adds WITH: {{ * MY_NAME }}" do
    sql = I_Dig_Sql.new
    sql[:MY_HERO] = "SELECT * FROM hero"
    sql[:MY_NAME] = "SELECT * FROM name"
    sql << %^
      {{ * MY_NAME }}
      {{ * MY_HERO }}
    ^
    sql(sql).should == sql(%^
      WITH
      MY_NAME AS (
        SELECT * FROM name
      ) ,
      MY_HERO AS (
        SELECT * FROM hero
      )
      SELECT * FROM MY_NAME
      SELECT * FROM MY_HERO
    ^)
  end # === it

  it "replaces text with content: {{ ! MY_NAME }}" do
    sql = I_Dig_Sql.new
    sql[:MY_HERO] = "SELECT * FROM hero"
    sql << %^
      {{ ! MY_HERO }}
    ^
    sql(sql).should == "SELECT * FROM hero"
  end # === it

end # === describe :I_Dig_Sql

describe '.new' do

  it "merges sql values: .new(i_dig_sql)" do
    first = I_Dig_Sql.new
    first[:hero] = "SELECT * FROM hero"
    second = I_Dig_Sql.new(first)
    second[:name] = "SELECT * FROM name"
    second << %^
      {{ ! hero }}
      {{ ! name }}
    ^
    sql(second).should == sql(%^
      SELECT * FROM hero
      SELECT * FROM name
    ^)
  end # === it

  it "combines all Strings" do
    i = I_Dig_Sql.new "SELECT ", " * ", " FROM ", " NAME "
    sql(i).should == sql("SELECT * FROM NAME")
  end # === it

end # === describe '.new'


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
