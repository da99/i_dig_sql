
class I_Dig_Sql

  METHODS = [
    :FROM,
    :LEFT,
    :RIGHT,
    :INNER,
    :AS,
    :COLLECT,
    [:GROUP_BY, :ORDER_BY, :ON, :SELECT, :ON]
  ]

  HAS_VAR          = /(\{\{|\<\<)[^\}\>]+(\}\}|\>\>)/
  SELECT_FROM_REG  = /SELECT.+FROM.+/
  COMMAS_OR_COLONS = /(\,|\:)+/
  ALL_UNDERSCORE   = /\A[_]+\Z/
  NOTHING          = "".freeze

  class << self
  end # === class self ===

  def initialize *args
    @stack = []
    @data  = {}
    @meta  = {
      :name     => nil,
      :alias    => nil,
      :raw      => nil,
      :fragment => nil,
      :sql      => nil
    }

    args.each { |a|

      case a

      when Symbol
        if @data[:name]
          @data[:alias] = a
        else
          @data[:name] = a
        end

      when String
        @data[:fragment] = a

      when Hash
        @data.merge! a

      else
        fail ArgumentError, "Invalid arg to init: #{a.inspect}"

      end  # === case

    }

  end # === def initialize

  %w{name alias raw fragment sql}.each { |k|
    eval <<-EOF.strip, nil, __FILE__, __LINE__
      def #{k}
        @meta[:#{k}]
      end
    EOF
  }

  def [] name
    fail ArgumentError, "Value not found: #{name.inspect}" unless @data.has_key?(name)
    @data[name]
  end

  def []= name, val
    fail ArgumentError, "Name already taken: #{name.inspect}" if @data.has_key?(name)
    @data[name] = val
  end

  def << str
    (@meta[:fragment] ||= "") << str
  end

  def to_pair
    [to_sql, vars!]
  end

  def to_meta *args
    compile *args
  end

  protected # ====================================================

  def prefix_raw sym
    "raw_#{sym.to_s.split('_').first}".to_sym
  end

  def prefix sym
    sym.to_s.split('_').first.to_sym
  end

  def WITH
    withs = @WITHS.dup
    maps  = []
    done  = {}
    while name = withs.shift
      next if done[name]
      if name == :DEFAULT || !self.has_key?(name)
        done[name] = true
        next
      end

      fragment = self[name].FRAGMENT
      fragment.gsub!(/^/, "    ") if ENV['IS_DEV']
      maps << "#{name} AS (\n#{fragment}\n  )"
      withs.concat self[name].WITHS
      done[name] = true
    end # === while name

    maps.join ",\n  "
  end

  def table_name one, two = nil
    if two
      k = two
      link_name = one
    else
      k = one
      link_name = nil
    end

    case
    when [:out_ftable, :in_ftable].include?(k)
      "#{real_table}_#{ meta[prefix(k)] }_#{meta[k]}"

    when link? && link_name && @data[link_name][:inner_join].include?(k)
      "#{self.name}_#{@data[link_name][:name]}_#{k}"

    else
      fail ArgumentError, "Unknown key for table name: #{k.inspect}"
    end
  end

  #
  # Examples:
  #
  #   field :in, :owner_id
  #   field :screen_name, :screen_name
  #   field :in
  #   field :raw_in
  #
  def field *args

    case args
    when [:out], [:in]
      "#{name}.#{data[args.last][:name]}"
    when [:raw, :out], [:raw, :in]
      "#{name}.#{self[:DEFAULT].data[args.last]}"
    when [:owner_id], [:type_id]
      "#{name}.#{args.first}"
    else
      fail ArgumentError, "Unknown args: #{args.inspect}"
    end # === case

  end # === def field

  def compile target = nil
    return(self[target].compile) if target && target != name

    if !@SQL
      compile_raw
    end

    {FRAGMENT: @FRAGMENT, SQL: @SQL, WITH: @WITH, VARS: vars!}
  end # === def to_sql

  def compile_raw
    @data[:raw].freeze

    s = @FRAGMENT = @data[:raw].dup

    while s[HAS_VAR] 
      s.gsub!(/\{\{\s?([^\}]+)\s?\}\}/) do |match|
        key = $1.strip.to_sym
        self[key]
        @WITHS << key
        key
      end

      s.gsub!(/\<\<\s?([^\>]+)\s?\>\>/) do |match|
        tokens = $1.gsub(COMMAS_OR_COLONS, NOTHING).split.map(&:to_sym)

        key = tokens.last

        if has_key?(key)

          tokens.pop
          target = self[key]

          if target.is_a?(Proc)
            target.call self, *tokens
          else
            field  = tokens.empty? ? nil : tokens.join(' ')

            if field
              @WITHS << key
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

    @WITH = if @WITHS.empty?
              ""
            else
              %^WITH\n  #{WITH()}\n\n^
            end

    @SQL = (@WITH + @FRAGMENT).strip
  end # === fragments_to_raw

  # === END: Rendering DSL ==========================================

end # === class I_Dig_Sql ===



