
class I_Dig_Sql
  class H < Hash

    def initialize *options
      @h_option = {}
      options.each { |name|
        case name
        when :allow_update
          @h_option[:allow_update] = true
        else
          fail ArgumentError, "Unknown option: #{name.inspect}"
        end
      }

      super()
    end

    def [] name
      fail ArgumentError, "Unknown key: #{name.inspect}" unless has_key?(name)
      super
    end

    def []= name, val
      if has_key?(name) && self[name] != val && !@h_option[:allow_update]
        fail ArgumentError, "Key already set: #{name.inspect}"
      end

      super
    end

    def merge_with_no_dups *args
      args.each { |h|
        h.each { |k,v|
          if has_key?(k) && self[k] != v
            fail ArgumentError, "Key already set: #{k.inspect}"
          else
            self[k] = v
          end
        }
      }
      self
    end

  end # === class H
end # === I_Dig_Sql

