require 'thrift'

module Stark
  module Converters
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
  end
end
