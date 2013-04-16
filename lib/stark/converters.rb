require 'thrift'
require 'set'

module Stark
  module Converters
    module BYTE
      module_function

      def type
        Thrift::Types::BYTE
      end

      def read(ip)
        ip.read_byte
      end

      def write(op, value)
        op.write_byte value
      end
    end

    module I16
      module_function

      def type
        Thrift::Types::I16
      end

      def read(ip)
        ip.read_i16
      end

      def write(op, value)
        op.write_i16 value
      end
    end

    module I32
      module_function

      def type
        Thrift::Types::I32
      end

      def read(ip)
        ip.read_i32
      end

      def write(op, value)
        op.write_i32 value
      end
    end

    module I64
      module_function

      def type
        Thrift::Types::I64
      end

      def read(ip)
        ip.read_i64
      end

      def write(op, value)
        op.write_i64 value
      end
    end

    module BOOL
      module_function

      def type
        Thrift::Types::BOOL
      end

      def read(ip)
        ip.read_bool
      end

      def write(op, value)
        op.write_bool value
      end
    end

    module DOUBLE
      module_function

      def type
        Thrift::Types::DOUBLE
      end

      def read(ip)
        ip.read_double
      end

      def write(op, value)
        op.write_double value
      end
    end

    module STRING
      module_function

      def type
        Thrift::Types::STRING
      end

      def read(ip)
        ip.read_string
      end

      def write(op, value)
        op.write_string value
      end
    end

    class Struct
      def initialize(cls)
        @class = cls
      end

      def type
        Thrift::Types::STRUCT
      end

      def read(ip)
        obj = @class.new
        obj.read ip
      end

      def write(op, value)
        value.write op
      end
    end

    class Enum
      def initialize(cls)
        @class = cls
      end

      def type
        Thrift::Types::I32
      end

      def read(ip)
        @class[ip.read_i32]
      end

      def write(op, value)
        op.write_i32 @class[value]
      end
    end

    class List
      def initialize(value)
        @value = value
      end

      def type
        Thrift::Types::LIST
      end

      def read(ip)
        vt, size = ip.read_list_begin

        if vt != @value.type
          raise TypeError, "List expected to be type: #{@value.type}"
        end

        v = @value

        Array.new(size) { v.read(ip) }
      ensure
        ip.read_list_end
      end

      def write(op, value)
        value = Array(value)

        op.write_list_begin @value.type, value.size

        c = @value
        value.each { |v| c.write op, v }

        op.write_list_end
      end

    end

    class Set
      def initialize(value)
        @value = value
      end

      def type
        Thrift::Types::SET
      end

      def read(ip)
        vt, size = ip.read_set_begin

        if vt != @value.type
          raise TypeError, "Set expected to be type: #{@value.type}"
        end

        v = @value

        ::Set.new(Array.new(size) { v.read(ip) })
      ensure
        ip.read_set_end
      end

      def write(op, value)
        value = ::Set.new(Array(value))

        op.write_list_begin @value.type, value.size

        c = @value
        value.each { |v| c.write op, v }

        op.write_list_end
      end

    end

    class Map
      def initialize(key, value)
        @key, @value = key, value
      end

      def type
        Thrift::Types::MAP
      end

      def read(ip)
        kt, vt, size = ip.read_map_begin

        if kt != @key.type || vt != @value.type
          raise TypeError, "Map expected to be type: (#{@key.type},#{@value.type})"
        end

        k, v = @key, @value

        {}.tap do |hash|
          size.times do
            hash[k.read(ip)] = v.read(ip)
          end
        end
      ensure
        ip.read_map_end
      end

      def write(op, value)
        op.write_map_begin @value.type, value.size

        value.each do |k,v|
          @key.write op, k
          @value.write op, v
        end

        op.write_map_end
      end

    end
  end
end
