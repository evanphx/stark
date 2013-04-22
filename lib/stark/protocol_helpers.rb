module Stark
  module ProtocolHelpers
    def expect(ip, expected, actual)
      if expected == actual
        yield
      else
        ip.skip actual unless actual == ::Thrift::Types::STOP
        nil
      end
    end

    def expect_list(ip, expected)
      actual, size = ip.read_list_begin
      if expected == actual
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
      if expected_key == actual_key && expected_value == actual_value
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
      if expected == actual
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
