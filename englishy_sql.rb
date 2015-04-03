
require 'pry'
require 'sequel'
DB = Sequel.mock

class Englishy_Sql

  Duplicate = Class.new RuntimeError

  def initialize
    @sql  = {}
    @vals = {}
    instance_eval(&(Proc.new))
  end # === def initialize

  def val name, v
    if @vals.has_key?(name) && @vals[name] != v
      fail Duplicate, "Already set w/different value: #{name.inspect}"
    end
  end

  def screen_name name
    val :SCREEN_NAME, name.to_s.strip.upcase
    sql(:SCREEN_NAME) {

      any! {
        owner_id.==(:AUDIENCE_ID)
        all {
          no_block
          any! {
            WORLD!
            allowed
          }
        }
      } # === any

      one!
    } # === sql
  end

  def post
    @sql = @sql.where(:id=> DB[:post].select(:id) )
  end # === def post

  def comments
    @sql = @sql.or(:parent_id=>DB[:comment].select(:id))
  end

  def sql *args
    case
    when args.empty?
      @sql.sql

    when args.size == 2
      name, v = args
      is_dup  = @sql.has_key?(name) && @sql[name] != v
      fail Duplicate, "Already set w/different value: #{name.inspect}" if is_dup

    else
      fail ArgumentError, "Unknown args: #{args.inspect}"

    end # === case
  end

end # === Englishy_Sql


puts(Englishy_Sql.new {
  table(:computer) {
    as(:comments)
    any! {
      is_owner
    }
  }
}.sql)

SELECT *
FROM screen_name
WHERE
  id = (SELECT id FROM screen_name WHERE screen_name = 'MEANIE_6294')
  AND (
  owner_id = :AUDIENCE_ID
    OR
    (
      :AUDIENCE_ID NOT IN  (BLOCKED)
      AND
      ( privacy = :WORLD
        OR
        (
          privacy = :PROTECTED
          AND
          :AUDIENCE_ID IN (
            ALLOWED
          )
        )
      )
    )
  )
