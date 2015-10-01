module Stark
  module ProtocolHelpers
    COERCION_TO_STRING = Hash.new {|h,k|
      lambda {|ip| ip.skip k; nil }
    }.update({
      ::Thrift::Types::BOOL   => lambda {|ip| ip.read_bool.to_s },
      ::Thrift::Types::BYTE   => lambda {|ip| ip.read_byte.to_s },
      ::Thrift::Types::I16    => lambda {|ip| ip.read_i16.to_s },
      ::Thrift::Types::I32    => lambda {|ip| ip.read_i32.to_s },
      ::Thrift::Types::I64    => lambda {|ip| ip.read_i64.to_s },
      ::Thrift::Types::DOUBLE => lambda {|ip| ip.read_double.to_s },
    })

    COERCION_FROM_STRING = Hash.new {|h,k|
      lambda {|val| nil }
    }.update({
      ::Thrift::Types::BOOL   => lambda {|val|
        val =~ /^(1|y|t|on)/ ? true : false },
      ::Thrift::Types::BYTE   => lambda {|val| val.to_i },
      ::Thrift::Types::I16    => lambda {|val| val.to_i },
      ::Thrift::Types::I32    => lambda {|val| val.to_i },
      ::Thrift::Types::I64    => lambda {|val| val.to_i },
      ::Thrift::Types::DOUBLE => lambda {|val| val.to_f },
    })

    def expect(ip, expected, actual)
      return nil if actual == ::Thrift::Types::STOP

      if expected == actual
        yield
      elsif expected == ::Thrift::Types::STRING
        COERCION_TO_STRING[actual][ip]
      elsif actual == ::Thrift::Types::STRING
        COERCION_FROM_STRING[expected][ip.read_string]
      else
        ip.skip actual
        nil
      end
    end

    def valid_element_type?(expected, actual)
      expected == actual ||
        expected == ::Thrift::Types::STRING ||
        actual == ::Thrift::Types::STRING
    end

    def expect_list(ip, expected)
      actual, size = ip.read_list_begin
      if valid_element_type?(expected, actual)
        yield actual, size
      else
        size.times { ip.skip actual }
        nil
      end
    ensure
      ip.read_list_end
    end

    def expect_map(ip, expected_key, expected_value)
      actual_key, actual_value, size = ip.read_map_begin
      if valid_element_type?(expected_key, actual_key) &&
          valid_element_type?(expected_value, actual_value)
        yield actual_key, actual_value, size
      else
        size.times do
          ip.skip actual_key
          ip.skip actual_value
        end
        nil
      end
    ensure
      ip.read_map_end
    end

    def expect_set(ip, expected)
      actual, size = ip.read_set_begin
      if valid_element_type?(expected, actual)
        yield actual, size
      else
        size.times { ip.skip actual }
        nil
      end
    ensure
      ip.read_set_end
    end

    def hash_cast(obj)
      return obj if obj.kind_of? Hash
      return obj.to_h if obj.respond_to? :to_h

      raise TypeError, "Unable to convert #{obj.class} to Hash"
    end

    THRIFT_TO_RUBY = {
      ::Thrift::Types::BOOL => [TrueClass, FalseClass, NilClass],
      ::Thrift::Types::BYTE => [Fixnum],
      ::Thrift::Types::I16 => [Fixnum],
      ::Thrift::Types::I32 => [Fixnum],
      ::Thrift::Types::I64 => [Fixnum],
      ::Thrift::Types::DOUBLE => [Float],
      ::Thrift::Types::STRING => [String],
      ::Thrift::Types::MAP    => [Hash],
      ::Thrift::Types::SET    => [Set],
      ::Thrift::Types::LIST   => [Array]
    }

    def value_for_write(val, expected, additional = nil)
      return val if val.nil?

      ruby_types = nil
      if additional
        case expected
        when ::Thrift::Types::STRUCT
          if Class === additional && # Struct or Exception
            (additional < Stark::Struct || additional < Stark::Exception)
            ruby_types = [additional]
          end
        when ::Thrift::Types::I32
          if Hash === additional # Enum hash
            ruby_types = [Symbol]
          end
        end
      else
        ruby_types = THRIFT_TO_RUBY[expected]
      end

      raise TypeError, "Unknown Thrift type #{expected}" unless ruby_types

      return val if ruby_types.any? {|t| t === val }

      if String === val
        obj = COERCION_FROM_STRING[expected][val]
        raise TypeError, "Cannot coerce #{val.class} to #{ruby_types.join(' ')}" unless obj
        return obj
      end

      case expected
      when ::Thrift::Types::BOOL
        return val
      when ::Thrift::Types::STRING
        return val.to_s
      when ::Thrift::Types::MAP
        return val.to_hash if val.respond_to?(:to_hash)
      when ::Thrift::Types::SET
        return Set.new(val.to_a) if val.respond_to?(:to_a)
      when ::Thrift::Types::LIST
        return val.to_a if val.respond_to?(:to_a)
      when ::Thrift::Types::BYTE, ::Thrift::Types::I16, ::Thrift::Types::I64
        return val.to_i if val.respond_to?(:to_i)
      when ::Thrift::Types::I32
        if Hash === additional # Enum hash
          return val.to_sym if val.respond_to?(:to_sym)
        end
        if additional
          return additional[val.to_i] if val.respond_to?(:to_i)
        else
          return val.to_i
        end
      when ::Thrift::Types::DOUBLE
        return val.to_f if val.respond_to?(:to_f)
      end
      raise TypeError, "Unexpected type #{val.class} (#{val.inspect}); was expecting #{ruby_types.join(' ')}"
    end
  end
end
