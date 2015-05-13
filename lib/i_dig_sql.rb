

require 'boxomojo'

class I_Dig_Sql

  Box = Boxomojo.new(
    :SELECT,
    :FROM, :LEFT, :RIGHT, :INNER,
    :AS, :ON,
    :GROUP_BY, :ORDER_BY
  )

  HAS_VAR          = /(\{\{|\<\<)[^\}\>]+(\}\}|\>\>)/
  SELECT_FROM_REG  = /SELECT.+FROM.+/
  COMMAS_OR_COLONS = /(\,|\:)+/
  ALL_UNDERSCORE   = /\A[_]+\Z/
  NOTHING          = "".freeze

  class << self

    def box_to_string arr
      h = {:SELECT=>[], :FROM=>[], :GROUP_BY=>[], :ORDER_BY=>[]}
      arr.each { |raw|
        name, args, blok = raw

        case name
        when :SELECT
          h[:SELECT] << args.join(' AS ')

        when :FROM, :LEFT, :RIGHT, :INNER
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
            str << "\n" << on.join(' AND ')
          end
          h[:FROM] << str

        when :GROUP_BY, :ORDER_BY
          h[name].concat args

        else
          fail ArgumentError, "Unknown: #{name.inspect}"
        end
      }

      <<-EOF
        SELECT
          #{h[:SELECT].empty? ? '*' : h[:SELECT].join("\n")}
        FROM
          #{h[:FROM].join "\n"}
        #{ h[:GROUP_BY].empty? ? '' : 'GROUP BY ' + h[:GROUP_BY].join(', ')}
        #{ h[:ORDER_BY].empty? ? '' : 'ORDER BY ' + h[:ORDER_BY].join(', ')}
      EOF
    end # === def box_to_string

    def string *args, &blok
      dig   = args.pop
      str   = args.shift || box_to_string(Box.new &blok)
      s     = str.dup
      withs = []

      while s[HAS_VAR] 
        s.gsub!(/\{\{\s?([^\}]+)\s?\}\}/) do |match|
          key = $1.strip.to_sym
          dig.sql(key)
          withs << key
          key
        end

        s.gsub!(/\<\<\s?([^\>]+)\s?\>\>/) do |match|
          tokens = $1.gsub(COMMAS_OR_COLONS, NOTHING).split.map(&:to_sym)

          key = tokens.last

          if has_key?(key)

            tokens.pop
            target = dig.sql key

            if target.is_a?(Proc)
              target.call self, *tokens
            else
              field  = tokens.empty? ? nil : tokens.join(' ')

              if field
                withs << key
                tokens.pop
                "SELECT #{field} FROM #{key}"
              else
                target.to_sql
              end
            end

          elsif has_key?(tokens.first)
            self[tokens.shift].call self, *tokens

          else
            fail ArgumentError, "Not found: #{$1}"

          end # === if has_key?
        end
      end # === while s HAS_VAR

      with = if withs.empty?
                ""
              else
                withs = withs.dup
                maps  = []
                done  = {}
                while name = withs.shift
                  next if done[name]
                  if name == :DEFAULT || !dig.has_key?(name)
                    done[name] = true
                    next
                  end

                  fragment = dig[name].FRAGMENT
                  fragment.gsub!(/^/, "    ") if ENV['IS_DEV']
                  maps << "#{name} AS (\n#{fragment}\n  )"
                  withs.concat dig[name].withs
                  done[name] = true
                end # === while name

                maps.join ",\n  "
                %^WITH\n  #{with()}\n\n^
              end

      (with + s)
    end # === def extract_withs

  end # === class self ===

  def initialize
    @stack = []
    @sqls  = {}
    @vars  = {}
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

  def sql name, *args, &blok
    case

    when args.size == 0 && !block_given?
      @sqls[name]

    when (args.size == 0 && block_given?) || args.size == 1
      fail ArgumentError, "Already set: #{name.inspect}" if @sqls.has_key?(name)

      @sqls[name] = I_Dig_Sql.string(*(args), self, &blok)
    else
      fail ArgumentError, "Unknown args: #{args.inspect}"

    end # === case
  end # === def sql

  def to_sql name, vars = {}
    [sql(name), @vars.merge(vars)]
  end # === def to_sql

end # === class I_Dig_Sql ===





