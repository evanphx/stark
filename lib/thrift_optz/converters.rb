module ThriftOptz
  module Converters
    module I32
      module_function

      def type
        Thrift::Types::I32
      end

      def read(ip)
        ip.read_i32
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
    end
  end
end
