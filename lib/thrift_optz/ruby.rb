require 'thrift_optz/ast'

module ThriftOptz
  class Ruby
    def initialize(stream=STDOUT)

      @namespace = nil
      @indent = 0
      @structs = {}

      @stream = stream


      o "require 'thrift_optz/client'"
      o "require 'thrift_optz/struct'"
      o "require 'thrift_optz/field'"
      o "require 'thrift_optz/converters'"
    end

    def process_namespace(ns)
      @namespace = ns.namespace if ns.lang == "rb"
    end

    def process_include(inc)
    end

    def process_struct(str)
      @structs[str.name] = str

      o "class #{str.name} < ThriftOptz::Struct"
      indent
      o "Fields = {"
      indent

      str.fields.each do |f|
        c = "ThriftOptz::Converters::#{f.type.upcase}"

        o "#{f.index} => ThriftOptz::Field.new(#{f.index}, '#{f.name}', #{c}),"
      end

      o ":count => #{str.fields.size}"

      outdent
      o "}"
      outdent
      o "end"

    end

    def o(str)
      @stream.print(" " * @indent)
      @stream.puts str
    end

    def indent
      @indent += 2
    end

    def outdent
      @indent -= 2
    end

    CoreTypes = {
      'i32' => "::Thrift::Types::I32",
      'string' => '::Thrift::Types::STRING'
    }

    ReadFunc = {
      'i32' => "read_i32",
      'string' => 'read_string',
      'void' => 'read_void'
    }

    WriteFunc = {
      'i32' => "write_i32",
      'string' => 'write_string'
    }

    def type(t)
      CoreTypes[t] || raise("unknown type - #{t}")
    end

    def wire_type(t)
      return "::Thrift::Types::STRUCT" if @structs[t]
      type t
    end

    def object_type(t)
      return t if @structs[t]
      type t
    end

    def read_func(t)
      ReadFunc[t] || raise("unknown type - #{t}")
    end

    def write_func(t)
      WriteFunc[t] || raise("unknown type - #{t}")
    end

    def output_struct(desc, obj)
      o "op.write_struct_begin '#{desc.name}'"

      desc.fields.each do |f|
        if desc = @structs[f.type]
          o "op.write_field_begin '#{f.name}', ::Thrift::Types::STRUCT, #{f.index}"
          output_struct desc, f.name
          o "op.write_field_end"
        else
          o "op.write_field_begin '#{f.name}', #{type(f.type)}, #{f.index}"
          o "op.#{write_func(f.type)} #{obj}.#{f.name}"
          o "op.write_field_end"
        end
      end

      o "op.write_field_stop"
      o "op.write_struct_end"
    end

    def input_struct(desc)
      o "ip.read_struct_begin"
      o "while true"
      o "  _, ftype, fid = iprot.read_field_begin"
      o "  break if ftype == ::Thrift::Types::STOP"
      o "  obj.set_from_index fid, "
      o "  ip.read_field_end"
      o "end"

      o "ip.read_struct_end"
    end

    def process_service(serv)
      o "module #{serv.name}"
      indent
      o "class Client < ThriftOptz::Client"
      indent

      o "Functions = {}"
      serv.functions.each do |func|
        o "Functions[\"#{func.name}\"] = {"

        o "    :args => {"

        func.arguments.each do |a|
          o "      #{a.index} => #{wire_type(a.type)}"
        end

        o "    }"
        o "  }"
      end

      serv.functions.each do |func|
        names = func.arguments.map { |f| f.name }.join(", ")

        o "def #{func.name}(#{names})"
        indent
        o "op = @oprot"
        o "op.write_message_begin '#{func.name}', ::Thrift::MessageTypes::CALL, 0"
        o "op.write_struct_begin \"#{func.name}_args\""

        func.arguments.each do |arg|
          if desc = @structs[arg.type]
            o "op.write_field_begin '#{arg.name}', ::Thrift::Types::STRUCT, #{arg.index}"
            output_struct desc, arg.name
            o "op.write_field_end"
          else
            o "op.write_field_begin '#{arg.name}', #{type(arg.type)}, #{arg.index}"
            o "op.#{write_func(arg.type)} #{arg.name}"
            o "op.write_field_end"
          end
        end

        o "op.write_field_stop"
        o "op.write_struct_end"
        o "op.write_message_end"
        o "op.trans.flush"

        o "ip = @iprot"
        o "_, mtype, _ = ip.read_message_begin"
        o "handle_exception mtype"

        o "ip.read_struct_begin"

        if func.return_type == "void"
          o "_, rtype, _ = ip.read_field_begin"
          o "result = nil"
        else
          if desc = @structs[func.return_type]
            o "_, rtype, rid = ip.read_field_begin"
            o "result = read_generic rtype, rid, #{desc.name}"
          else
            o "_, rtype, _ = ip.read_field_begin"
            o "if rtype == #{type(func.return_type)}"
            o "  result = ip.#{read_func(func.return_type)}"
            o "end"
          end

          o "_, rtype, rid = ip.read_field_begin"
        end

        o "fail if rtype != ::Thrift::Types::STOP"

        o "ip.read_struct_end"
        o "ip.read_message_end"
        o "return result"

        outdent

        o "end"
      end

      outdent
      o "end"

      outdent
      o "end"
    end
  end

end

