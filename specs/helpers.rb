

require "Bacon_Colored"
require "awesome_print"
require "unindent"
require "rouge"


module Kernel
  def aputs *args
    ap *args, :indent=>-2
  end

  def asql raw
    base = raw.split("\n").detect { |l|
      !l.empty?
    }
    prefix = base.split(/[^\ ]+/).first
    indent = (prefix && prefix.size) || 0
    src = if indent.zero?
            raw
          else
            raw.split("\n").map { |l|
              if l.index(prefix) != 0
                prefix + l
              else
                l
              end
            }.join "\n"
          end

    puts "----------------------"
    puts Rouge::Formatters::Terminal256.new.format(
      Rouge::Lexers::SQL.new.lex(
        src.unindent
      )
    )
    puts "----------------------"
  end

end # === module Kernel

def sql o
  case o
  when String
    o.split.join(" ")

  when I_Dig_Sql::H
    sql o[:complete]

  when Array
    sql o.first

  else
    sql(o.to_sql)

  end # === case
end # === def sql


