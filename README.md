# I\_Dig\_Sql

My way of managing SQL fragments using Ruby.

# Warning:

You will hate using this.
Instead, use:

  * [Arel](http://github.com/rails/arel).
  * K'bam [https://github.com/vilnius-leopold/kbam](https://github.com/vilnius-leopold/kbam)

# History

I had trouble maintaining BIG sql queries.

I tried many things.

The best way (within my preferences)
was to use sub-queries, CTEs, avoid joins as much as possible,
and this gem to manage SQL fragments and CTEs.

Naturally, you would want to use prepared statements, compiled wat-cha-me-call-its,
  functions, views, thing-ma-jig-ers, and other tools available in your RDBMS.

So this gem is for lazy, stupid people like me.

# Usage

Please note that none of this is ready yet.

```ruby

  require 'i_dig_sql'

  sql = I_Dig_Sql.new
  sql[:HEROES]   = "SELECT id FROM hero WHERE id = :PERSON_ID"
  sql[:VILLIANS] = "SELECT id FROM villian" WHERE id = :PERSON_ID"
  sql << %^
    SELECT *
    FROM people
    WHERE
      id IN ({{{HEROES}}})
      AND
      id IN ({{{VILLIANS}}})
  ^

  sql.var :PERSON_ID, 1

  string, vars = sql.to_sql

  require "sequel"
  DB = Sequel.connect "your-string-here"
  DB[string, vars].all

```


