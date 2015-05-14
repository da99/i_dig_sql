

describe :I_Dig_Sql do

  it "runs" do
    dig = I_Dig_Sql.new
    dig.sql :heroes do
      FROM(:tbl, :heroes) {
        SELECT(:nickname, :name)
      }
    end

    sql(dig.sql(:heroes)).should == sql("SELECT heroes.nickname AS name FROM tbl heroes")
  end # === it

  it "runs the code from README.md" do
    readme = File.read(File.expand_path(File.dirname(__FILE__) + '/../README.md'))
    code   = (readme[/```ruby([^`]+)```/] && $1).split("\n").map { |l| l.sub('puts ', '') }.join("\n")
    line   = 0
    readme.split("\n").detect { |l| line = line + 1; l['```ruby'] }
    should.not.raise {
      eval(code, nil, 'README.md', line)
    }
  end # === it

  it "adds WITH: {{MY_NAME}}" do
    sql = I_Dig_Sql.new
    sql.sql :MY_HERO, "SELECT * FROM hero"
    sql.sql :MY_NAME, "SELECT * FROM name"
    sql.sql :SQL, %^
      {{MY_HERO}}
      {{MY_NAME}}
    ^
    sql(sql.sql :SQL).should == sql(%^
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

  %w{ * id }.each { |s|
    it "adds WITH: {{ MY_NAME #{s} }}" do
      sql = I_Dig_Sql.new
      sql.sql :MY_HERO, "SELECT id, p_id FROM hero"
      sql.sql :MY_NAME, "SELECT id, n_id FROM name"
      sql.sql :SQL, %^
        {{ MY_NAME #{s} }}
        {{ MY_HERO #{s} }}
      ^
      sql(sql.sql :SQL).should == sql(%^
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

    it "replaces text with content: {{ MY_NAME #{s} }}" do
      sql = I_Dig_Sql.new
      sql.sql :MY_HERO, "SELECT * FROM hero"
      sql.sql :SQL,     " {{ MY_HERO #{s} }} "
      sql(sql.sql :SQL).should == "WITH MY_HERO AS ( SELECT * FROM hero ) SELECT #{s} FROM MY_HERO"
    end # === it
  }

end # === describe :I_Dig_Sql


