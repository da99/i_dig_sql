
require "i_dig_sql/H"

class I_Dig_Sql

  include Enumerable

  HAS_VAR = /(\{\{|\<\<)[^\}\>]+(\}\}|\>\>)/
  SELECT_FROM_REG = /SELECT.+FROM.+/


  ALL_UNDERSCORE   = /\A[_]+\Z/
  COMBO_LEFT_RIGHT = [:left, :left, :right, :right]
  COMBO_OUT_IN     = [:out, :in, :out, :in]

  Duplicate = Class.new RuntimeError

  class << self
  end # === class self ===

  attr_reader :digs, :WITHS, :data
  def initialize *args
    @WITH     = nil
    @FRAGMENT = nil
    @SQL      = nil
    @WITHS    = []

    @digs  = []
    @data  = H.new(:allow_update)
    .merge!(
      :name  => nil,
      :raw   => nil,
      :vars  => H.new,
      :procs => H.new
    )

    args.each { |a|

      case a

      when Symbol
        @data[:name] = a

      when I_Dig_Sql
        @digs << a

      when String
        @data.merge!(:raw=>a)

      when Hash, H
        if a.has_key?(:raw)
          @data.merge! a
        else
          @data[:vars].merge! a
        end

      else
        fail ArgumentError, "Unknown arg: #{a.inspect}"

      end  # === case

    }

  end # === def initialize

  %w{name raw vars}.each { |k|
    eval <<-EOF.strip, nil, __FILE__, __LINE__
      def #{k}
        @data[:#{k}]
      end
    EOF
  }

  def vars!
    vars = H.new.merge!(@data[:vars])

    @digs.reverse.inject(vars) { |memo, dig|
      if dig != self
        memo.merge! dig.vars
      end
      memo
    }
  end

  def has_key? name
    !!(search name)
  end

  def search name
    fail ArgumentError, "No name specified: #{name.inspect}" if !name
    return self if self.name == name
    found = false
    if @data[:procs].has_key?(name)
      return @data[:procs][name]
    end

    @digs.reverse.detect { |d|
      found = if d.name == name
                d
              elsif d.data[:procs].has_key?(name)
                d.data[:procs][name]
              else
                d.digs.detect { |deep|
                  found = deep if deep.name == name
                  found = deep.data[:procs][name] if deep.data[:procs].has_key?(name)
                  found
                }
              end
    }
    found
  end

  def [] name
    found = search(name)
    fail ArgumentError, "SQL not found for: #{name.inspect}" unless found
    found
  end

  def []= name, val
    fail ArgumentError, "Name already taken: #{name.inspect}" if has_key?(name)

    case val
    when String
      @digs << I_Dig_Sql.new(self, name, val)

    when Hash, H
      case
      when val[:name] == :DEFAULT
        @digs << I_Dig_Sql.new(:DEFAULT, val)
      when val[:raw]
        @data.merge! val
      else
        @digs << I_Dig_Sql.new(self, name, val)
      end

    when I_Dig_Sql
      @digs << val

    when Proc
      @data[:procs][name] = val

    else
      fail ArgumentError, "Unknown class: #{name.inspect} -> #{val.class}"

    end # === case
  end

  def each
    digs = @digs.reverse
    digs.unshift self
    if block_given?
      digs.each { |d| yield d.name, d }
    else
      digs.each
    end
  end


  def << str
    (@data[:raw] ||= "") << str
  end

  def has_raw?
    !!(@data[:raw] && !@data[:raw].strip.empty?)
  end

  def to_pair
    [to_sql, vars!]
  end

  def to_meta *args
    compile *args
  end

  def to_sql *args
    compile(*args)[:SQL]
  end

  %w{ FRAGMENT SQL }.each { |k|
    eval <<-EOF.strip, nil, __FILE__, __LINE__ + 1
      def #{k}
        return @#{k} if @SQL
        to_meta[:#{k}]
      end
    EOF
  }

  private # ==========================================

  def prefix_raw sym
    "raw_#{sym.to_s.split('_').first}".to_sym
  end

  def prefix sym
    sym.to_s.split('_').first.to_sym
  end

  protected(
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
  ) # === protected

  #
  # Examples:
  #
  #   field :in, :owner_id
  #   field :screen_name, :screen_name
  #   field :in
  #   field :raw_in
  #
  protected(
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
  )

  protected def compile target = nil
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
        key = $1.to_sym
        @WITHS << key
        key
      end

      s.gsub!(/\<\<\s?([^\>]+)\s?\>\>/) do |match|
        tokens = $1.split

        key = tokens.last.to_sym

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

        elsif has_key?(tokens.first.to_sym)
          self[tokens.shift.to_sym].call self, *tokens

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

  # === END: Rendering DSL ==========================================

end # === class I_Dig_Sql ===



