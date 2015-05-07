
class I_Dig_Sql

  END_COMMA = /,\Z/
  TABLE_NAME = /[a-z0-9\_]+/

  class << self

    def to_hash str
      h = {}
      key = nil
      str.split("\n").each { |line|
        next if h.empty? && line.strip.empty?
        case
        when line[/\ *(WITH|SELECT|FROM|ORDERY\ +BY|LIMIT|GROUP\ +BY)\ *(.{0,})\Z/]
          key    = $1
          h[key] = []
          line   = $2
        end

        stripped = line.strip

        if !stripped.empty?
          stripped.sub!(END_COMMA, '') if key == 'SELECT'
          h[key] << stripped
        end
      } # === each

      underscore h
    end # === def to_hash

    def underscore h
      from = []
      tables = []
      h['FROM'].each { |line|
        case

        when from.empty? && line[/\A\ *(#{TABLE_NAME})(\ +AS\ +(#{TABLE_NAME}))?\ *\Z/]
          tables << ($3 || $1)

        when line['JOIN ']
          pieces = line.split(/\ *[A-Z]+\ *JOIN\ +/)
          while table = pieces.shift
            name = table.split.last
            tables << name if name
          end

        end # === case

        line.gsub!(/(_+)\./) { |match|
          name = tables[-($1.size)]
          fail ArgumentError, "Unknown value for: #{$1.inspect} in #{tables.inspect}" if !name
          "#{name}."
        }
        from << line
      }

      h['FROM'] = from
      h
    end

  end # === class << self

end # === I_Dig_Sql
