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
  end
end
