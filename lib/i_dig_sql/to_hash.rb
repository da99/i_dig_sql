
class I_Dig_Sql

  class << self

    def to_hash str
      h = {}
      key = nil
      str.split("\n").each { |line|
        next if h.empty? && line.strip.empty?
        case
        when line[/\ *([A-Z][A-Z\ ]+[A-Z])\ *(.{0,})\Z/]
          key    = $1
          h[key] = []
          line   = $2
        end
        stripped = line.strip
        h[key] << stripped unless stripped.empty?
      } # === each
      h
    end

  end # === class << self

end # === I_Dig_Sql
