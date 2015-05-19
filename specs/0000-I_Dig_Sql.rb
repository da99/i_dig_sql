

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
  } # === %w{}

  it "renders nested replacements"  do
    i = I_Dig_Sql.new
    i.sql :THIRD,  "SELECT id FROM phantom"
    i.sql :SECOND, " {{ THIRD }}  "
    i.sql :FIRST,  " {{ SECOND }} "
    i.sql :SQL,    " {{ FIRST }}  "
    sql(i.sql :SQL).should == sql(
      <<-EOF
        WITH
        FIRST AS ( SECOND ),
        SECOND AS ( THIRD ),
        THIRD AS ( SELECT id FROM phantom )
        FIRST
      EOF
    )
  end # === it

  it "prints CTE definitions once, if used multiple times" do
    i = I_Dig_Sql.new
    i.sql :my_cte, "SELECT * FROM my"
    i.sql :SQL, <<-EOF
      {{my_cte}}
      {{my_cte}}
    EOF
    sql(i.sql :SQL).should == sql(%^
      WITH
      my_cte AS (
        SELECT * FROM my
      )
      my_cte
      my_cte
    ^)
  end # === it

end # === describe :I_Dig_Sql


describe ":pair" do

  it "returns an array of: [string, hash]" do
    s = "select * from THE_WORLD"
    i = I_Dig_Sql.new
    i.sql :SQL, s
    i.pair(:SQL).should == [s, {}]
  end # === it

  it "merges the hash passed to it" do
    s = "select * from THE_UNI"
    i = I_Dig_Sql.new
    i.sql :SQL, s
    i.pair(:SQL, {:a=>:b}).should == [s, {:a=>:b}]
  end # === it

  it "does not save :vars passed to it" do
    s = "select * from THE_UNI"
    i = I_Dig_Sql.new
    i.sql :SQL, s
    i.pair(:SQL, {:a=>:b})
    i.vars.should == {}
  end # === it

end # === describe pair


describe ":box" do

  it "turns a box into a String" do
    sql = I_Dig_Sql.new
    sql.sql :joins do

      FROM(:n, :notes) {
        SELECT(:long_name, :name)
      }

      LEFT(:f, :fails) {
        ON('_.n = __.n')
        SELECT(:long_name, :name)
      }

    end

    sql(sql.sql :joins).should == sql(%^
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
