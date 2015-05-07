
class I_Dig_Sql

  END_COMMA = /,\Z/

  class << self

    def to_hash str
      h = {}
      key = nil
      str.split("\n").each { |line|
        next if h.empty? && line.strip.empty?
        case
        when line[/\ *(WITH|SELECT|FROM|ORDERY BY|LIMIT|GROUP BY)\ *(.{0,})\Z/]
          key    = $1
          h[key] = []
          line   = $2
        end
        stripped = line.strip
        if !stripped.empty?
          if key == 'SELECT'
            stripped.sub!(END_COMMA, '')
          end
          h[key] << stripped
        end
      } # === each
      h
    end

  end # === class << self

end # === I_Dig_Sql
