

describe :I_Dig_Sql do

  it "runs the code from README.md" do
    readme = File.read(File.expand_path(File.dirname(__FILE__) + '/../README.md'))
    code   = readme[/```ruby([^`]+)```/] && $1
    line   = 0
    readme.split("\n").detect { |l| line = line + 1; l['```ruby'] }
    should.not.raise {
      eval(code, nil, 'README.md', line)
    }
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
      ),
      MY_NAME AS (
        SELECT * FROM name
      )
      MY_HERO
      MY_NAME
    ^)
  end

  it "replaces text with content: << MY_NAME >>" do
    sql = I_Dig_Sql.new
    sql[:MY_HERO] = "SELECT * FROM hero"
    sql << %^
      << MY_HERO >>
    ^
    sql(sql).should == "SELECT * FROM hero"
  end # === it

  %w{ * id }.each { |s|
    it "adds WITH: << #{s} MY_NAME >>" do
      sql = I_Dig_Sql.new
      sql[:MY_HERO] = "SELECT id, p_id FROM hero"
      sql[:MY_NAME] = "SELECT id, n_id FROM name"
      sql << %^
        << #{s} MY_NAME >>
        << #{s} MY_HERO >>
      ^
      sql(sql).should == sql(%^
        WITH
        MY_NAME AS (
          SELECT id, n_id FROM name
        ),
        MY_HERO AS (
          SELECT id, p_id FROM hero
        )
        SELECT #{s} FROM MY_NAME
        SELECT #{s} FROM MY_HERO
      ^)
    end # === it
  }

end # === describe :I_Dig_Sql


