require 'stark/parser'

class Stark::Parser
  module AST
    class Namespace
      def accept(obj)
        obj.process_namespace self
      end
    end

    class Include
      def accept(obj)
        obj.process_include self
      end
    end

    class Struct
      def accept(obj)
        obj.process_struct self
      end
    end

    class Field
      def accept(obj)
        obj.process_field self
      end
    end

    class Function
      def accept(obj)
        obj.process_function self
      end
    end

    class Service
      def accept(obj)
        obj.process_service self
      end
    end

    class Enum
      def accept(obj)
        obj.process_enum self
      end
    end

    class Exception
      def accept(obj)
        obj.process_exception self
      end
    end
  end
end
