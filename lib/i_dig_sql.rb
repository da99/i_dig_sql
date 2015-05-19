

require 'i_dig_sql/H'
require 'boxomojo'

class I_Dig_Sql

  Box = Boxomojo.new(
    :SELECT,
    :FROM, :LEFT, :RIGHT, :INNER,
    :AS, :ON,
    :GROUP_BY, :ORDER_BY
  )

  HAS_VAR          = /(\{\{)[^\}\>]+(\}\})/
  SELECT_FROM_REG  = /SELECT.+FROM.+/
  COMMAS_OR_COLONS = /(\,|\:)+/
  ALL_UNDERSCORE   = /\A[_]+\Z/
  NOTHING          = "".freeze

  class << self

    def box_to_string arr
      h = {:SELECT=>[], :FROM=>[], :GROUP_BY=>[], :ORDER_BY=>[]}
      table_name_stack = []
      arr.each { |raw|
        name, args, blok = raw

        case name
        when :SELECT
          h[:SELECT] << args.join(' AS ')

        when :FROM, :LEFT, :RIGHT, :INNER
          table_name_stack.push args.last
          str = if name == :FROM
                  args.join(' ')
                else
                  "#{name} JOIN #{args.join ' '}"
                end

          table_name = args.last

          if blok
            on = []
            blok.each { |raw|
              args = raw.dup
              name = args.shift
              blok = args.pop
              case name
              when :ON
                on << args

              when :SELECT
                h[:SELECT] << "#{table_name}.#{args.join ' AS '}"

              else
                fail ArgumentError, "Unknown name: #{name.inspect}"
              end
            }

            ( str << "\nON " << on.join(' AND ') ) unless on.empty?
          end

          str.gsub!(/\b([_]+)(?=\.)/) { |match|
            t_name = table_name_stack[match.size * -1]
            fail ArgumentError, "Name not found for: #{match}" if !t_name
            t_name
          }

          h[:FROM] << str

        when :GROUP_BY, :ORDER_BY
          h[name].concat args

        else
          fail ArgumentError, "Unknown: #{name.inspect}"
        end
      }

      <<-EOF
        SELECT
          #{h[:SELECT].empty? ? '*' : h[:SELECT].join(",\n")}
        FROM
          #{h[:FROM].join "\n"}
        #{ h[:GROUP_BY].empty? ? '' : 'GROUP BY ' + h[:GROUP_BY].join(', ')}
        #{ h[:ORDER_BY].empty? ? '' : 'ORDER BY ' + h[:ORDER_BY].join(', ')}
      EOF
    end # === def box_to_string

    #
    #  Examples:
    #    string( "...", dig)
    #    string( dig ) { FROM ... }
    #
    def string *args, &blok
      dig   = args.pop
      str   = args.shift || box_to_string(Box.new &blok)
      s     = str.dup
      withs = []

      while s[HAS_VAR]
        s.gsub!(/\{\{\s?([^\}]+)\s?\}\}/) do |match|
          pieces = $1.split
          name   = pieces.shift
          key    = name.to_sym
          args   = pieces
          withs << key
          withs.concat(dig.sql(key)[:withs]) if dig.sqls.has_key?(key)
          case args.size
          when 0
            name
          else
            "SELECT #{args.join ', '} FROM #{name}"
          end # === case
        end
      end # === while s HAS_VAR

      with = if withs.empty?
               ""
             else
               maps  = []
               done  = {}
               withs.uniq!
               withs.each { |name|
                 next if done[name]
                 fragment = dig.sql(name)[:base]
                 (fragment = fragment.gsub(/^/, "    ")) if ENV['IS_DEV']
                 maps << "#{name} AS (\n#{fragment}\n  )"
                 done[name] = true
               } # === each withs

               %^WITH\n  #{maps.join ",\n  "}\n\n^
             end

      [with + s, s, withs]
    end # === def extract_withs

  end # === class self ===

  attr_reader :vars, :sqls
  def initialize
    @stack = []
    @sqls  = H.new
    @vars  = H.new
  end # === def initialize

  def var name, *args
    case args.size

    when 0
      @vars[name]

    when 1
      @vars[name] = args.first

    else
      fail ArgumentError, "Unknown args: #{args.inspect}"

    end # === case
  end # === def var

  # Example:
  #   sql(:name)
  #   sql(:name, 'string')
  #   sql(:name) { FROM ... }
  #
  def sql name, *args, &blok
    case

    when args.size == 0 && !block_given?
      @sqls[name]

    when (args.size == 0 && block_given?) || args.size == 1
      @sqls[name] = H.new
      @sqls[name][:complete], @sqls[name][:base], @sqls[name][:withs] = I_Dig_Sql.string(*(args), self, &blok)

    else
      fail ArgumentError, "Unknown args: #{args.inspect}"

    end # === case
  end # === def sql

  def pair name = :SQL, vars = {}
    @vars.freeze unless @vars.frozen?
    [sql(name)[:complete], @vars.merge(vars)]
  end # === def to_sql

end # === class I_Dig_Sql ===





