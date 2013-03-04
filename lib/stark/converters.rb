require 'thrift'

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
      end

      def write(op, value)
        value = Array(value)

        op.write_list_begin @value.type, value.size

        c = @value
        value.each { |v| c.write op, v }

        op.write_list_end
      end

    end
  end
end
