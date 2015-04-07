# I\_Dig\_Sql


I'm still learning how to write decent SQL queries
in Postgresql 9.4.  I'm using this to manage
sub-queries in complicated SQL queries.

You won't find this useful and I am too lazy/busy
to write decent documentation for something
no one but me will use for esoteric purposes.

Instead, this to for SQL + Ruby:

  * [Arel](http://github.com/rails/arel).
  * K'bam [https://github.com/vilnius-leopold/kbam](https://github.com/vilnius-leopold/kbam)
  * Sequel [http://sequel.jeremyevans.net/rdoc/files/doc/querying_rdoc.html](http://sequel.jeremyevans.net/rdoc/files/doc/querying_rdoc.html)

# Usage

Please note that none of this is ready yet.

```ruby

  require 'i_dig_sql'

  sql = I_Dig_Sql.new
  sql[:HEROES]   = "SELECT id FROM hero    WHERE id = :PERSON_ID"
  sql[:VILLIANS] = "SELECT id FROM villian WHERE id = :PERSON_ID"
  sql << %^
    SELECT *
    FROM people
    WHERE
      id IN ( << HEROES >> AND status = :ALIVE)
      OR
      id IN (SELECT ID FROM {{ HEROES }} AND status = :ALIVE)
      OR
      id IN ( << * HEROES >> )
      OR
      id IN ( << patron_id VILLIANS >> )
      OR
      id IN ( << VILLIANS >> )
  ^

  sql.to_sql

```


