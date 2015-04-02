
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

end # === describe '.new'
