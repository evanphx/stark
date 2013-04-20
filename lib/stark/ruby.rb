require 'stark/ast'

module Stark
  class Ruby
    def initialize(stream=STDOUT)

      @namespace = nil
      @indent = 0
      @structs = {}
      @enums = {}
      @exceptions = {}

      @stream = stream


      o "require 'set'"
      o "require 'stark/client'"
      o "require 'stark/struct'"
      o "require 'stark/field'"
      o "require 'stark/converters'"
      o "require 'stark/processor'"
      o "require 'stark/exception'"
    end

    def run(ast)
      ast.each { |a| a.accept self }
      close
    end

    def close
      if @namespace
        outdent
        o "end"
      end
    end

    def process_namespace(ns)
      return unless [nil, 'rb'].include?(ns.lang)
      @namespace = ns.namespace.gsub('.', '::')
      parts = @namespace.split('::')
      if parts.length > 1
        0.upto(parts.length - 2) do |i|
          o "module #{parts[0..i].join('::')}; end unless defined?(#{parts[0..i].join('::')})"
        end
      end
      o "module #{@namespace}"
      indent
    end

    def process_include(inc)
    end

    def process_enum(enum)
      e = "Enum_#{enum.name}"
      o "#{e} = Hash.new { |h,k| p [:bad, k]; h[k] = -1 }"

      idx = 0
      enum.values.each do |f|
        o "#{e}[#{idx}] = :'#{f}'"
        o "#{e}[:'#{f}'] = #{idx}"
        idx += 1
      end

      @enums[enum.name] = enum
    end

    def converter(t)
      if t.kind_of? Stark::Parser::AST::List
        "Stark::Converters::List.new(#{converter(t.value)})"
      elsif t.kind_of? Stark::Parser::AST::Set
        "Stark::Converters::Set.new(#{converter(t.value)})"
      elsif t.kind_of? Stark::Parser::AST::Map
        "Stark::Converters::Map.new(#{converter(t.key)}, #{converter(t.value)})"
      elsif BUILTINS.include? t.downcase
        "Stark::Converters::#{t.upcase}"
      elsif desc = @structs[t]
        "Stark::Converters::Struct.new(#{t})"
      elsif desc = @enums[t]
        "Stark::Converters::Enum.new(Enum_#{t})"
      else
        raise "Unknown type <#{t}>"
      end
    end

    def process_struct(str)
      @structs[str.name] = str

      o "class #{str.name} < Stark::Struct"
      indent
      o "Fields = {"
      indent

      fields = str.fields.map do |f|
        c = converter f.type
        "#{f.index} => Stark::Field.new(#{f.index}, '#{f.name}', #{c})"
      end

      o "   #{fields.join(', ')}"

      outdent
      o "}"

      str.fields.each do |f|
        o "def #{f.name}; @fields['#{f.name}']; end"
        o "def #{f.name}=(obj); @fields['#{f.name}'] = obj; end"
      end

      outdent
      o "end"

    end

    BUILTINS = %w!bool byte i16 i32 i64 double string!

    def process_exception(str)
      @exceptions[str.name] = str

      o "class #{str.name} < Stark::Exception"
      indent

      str.name.replace "Struct"
      process_struct(str)

      str.fields.each do |f|
        o "def #{f.name}; @struct.#{f.name}; end"
        o "def #{f.name}=(obj); @struct.#{f.name} = obj; end"
      end

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
      'bool' => "::Thrift::Types::BOOL",
      'byte' => "::Thrift::Types::BYTE",
      'double' => "::Thrift::Types::DOUBLE",
      'i16' => "::Thrift::Types::I16",
      'i32' => "::Thrift::Types::I32",
      'i64' => "::Thrift::Types::I64",
      'string' => '::Thrift::Types::STRING',
      'struct' => '::Thrift::Types::STRUCT',
      'map' => '::Thrift::Types::MAP',
      'set' => '::Thrift::Types::SET',
      'list' => '::Thrift::Types::LIST'
    }

    ReadFunc = {
      'bool' => 'read_bool',
      'byte' => 'read_byte',
      'double' => 'read_double',
      'i16' => "read_i16",
      'i32' => "read_i32",
      'i64' => "read_i64",
      'string' => 'read_string',
    }

    WriteFunc = {
      'bool' => 'write_bool',
      'byte' => 'write_byte',
      'double' => 'write_double',
      'i16' => "write_i16",
      'i32' => "write_i32",
      'i64' => "write_i64",
      'string' => 'write_string',
    }

    def type(t)
      CoreTypes[t] || raise("unknown type - #{t}")
    end

    def wire_type(t)
      return "::Thrift::Types::STRUCT" if @structs[t]
      return "::Thrift::Types::I32" if @enums[t]

      case t
      when Stark::Parser::AST::Map
        "::Thrift::Types::MAP"
      when Stark::Parser::AST::List
        "::Thrift::Types::LIST"
      when Stark::Parser::AST::Set
        "::Thrift::Types::SET"
      else
        type t
      end
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

    def read_type(t, lhs, found_type = 'rtype')
      o "if #{found_type} != #{wire_type(t)}"
      o "  handle_unexpected #{found_type}"
      o "else"
      if desc = @structs[t]
        o "  #{lhs} = read_struct ip, #{found_type}, rid, #{desc.name}"
      elsif desc = @enums[t]
        o "  #{lhs} = Enum_#{desc.name}[ip.read_i32]"
      elsif t.kind_of? Stark::Parser::AST::Map
        o "  kt, vt, size = ip.read_map_begin"
        o "  if kt == #{wire_type(t.key)} && vt == #{wire_type(t.value)}"
        o "    _hash = {}"
        o "    size.times do"
        indent
        read_type(t.key, "k", "kt")
        read_type(t.value, "v", "vt")
        outdent
        o "      _hash[k] = v"
        o "    end"
        o "    #{lhs} = _hash"
        o "  else"
        o "    handle_bad_map size"
        o "  end"
        o "  ip.read_map_end"
      elsif t.kind_of? Stark::Parser::AST::List
        o "  vt, size = ip.read_list_begin"
        o "  if vt == #{wire_type(t.value)}"
        o "    #{lhs} = Array.new(size) do"
        indent
        read_type t.value, "element", "vt"
        outdent
        o "      element"
        o "    end"
        o "  else"
        o "    handle_bad_list size"
        o "  end"
        o "  ip.read_list_end"
      elsif t.kind_of? Stark::Parser::AST::Set
        o "  vt, size = ip.read_set_begin"
        o "  if vt == #{wire_type(t.value)}"
        o "    _arr = Array.new(size) do"
        indent
        read_type t.value, "element", "vt"
        outdent
        o "      element"
        o "    end"
        o "    #{lhs} = ::Set.new(_arr)"
        o "  else"
        o "    handle_bad_list size"
        o "  end"
        o "  ip.read_list_end"
      else
        o "  #{lhs} = ip.#{read_func(t)}"
      end
      o "end"
    end

    def write_type(ft, name)
      if desc = @structs[ft]
        output_struct desc, name
      elsif desc = @enums[ft]
        o "op.write_i32 Enum_#{desc.name}[#{name}.to_sym]"
      elsif ft.kind_of? Stark::Parser::AST::Map
        o "#{name} = hash_cast #{name}"
        o "op.write_map_begin(#{wire_type(ft.key)}, #{wire_type(ft.value)}, #{name}.size)"
        o "#{name}.each do |k,v|"
        indent
        write_type ft.key, "k"
        write_type ft.value, "v"
        outdent
        o "end"
        o "op.write_map_end"
      elsif ft.kind_of? Stark::Parser::AST::List
        o "#{name} = Array(#{name})"
        o "op.write_list_begin(#{wire_type(ft.value)}, #{name}.size)"
        o "#{name}.each do |v|"
        indent
        write_type ft.value, "v"
        outdent
        o "end"
        o "op.write_list_end"
      elsif ft.kind_of? Stark::Parser::AST::Set
        o "op.write_list_begin(#{wire_type(ft.value)}, #{name}.size)"
        o "#{name}.each do |v|"
        indent
        write_type ft.value, "v"
        outdent
        o "end"
        o "op.write_set_end"
      elsif ft != "void"
        o "op.#{write_func(ft)} #{name}"
      end
    end

    def write_field(ft, name, idx)
      o "op.write_field_begin '#{name}', #{wire_type(ft)}, #{idx}"
      write_type ft, name
      o "op.write_field_end"
    end

    def output_struct(desc, obj)
      o "op.write_struct_begin '#{desc.name}'"

      desc.fields.each do |f|
        o "if #{f.name} = #{obj}.#{f.name}"
        indent
        write_field f.type, f.name, f.index
        outdent
        o "end"
      end

      o "op.write_field_stop"
      o "op.write_struct_end"
    end

    def write_processor(serv)
      o "class Processor < Stark::Processor"
      indent

      serv.functions.each do |func|
        o "def process_#{func.name}(seqid, ip, op)"
        indent

        o "ip.read_struct_begin"
        args = Array(func.arguments)
        o "args = Array.new(#{args.size})"

        args.each do |arg|
          o "_, rtype, rid = ip.read_field_begin"
          read_type arg.type, "args[#{arg.index - 1}]"
          o "ip.read_field_end"
        end

        o "_, rtype, _ = ip.read_field_begin"
        o "fail unless rtype == ::Thrift::Types::STOP"
        o "ip.read_struct_end"
        o "ip.read_message_end"

        if t = func.throws
          o "result = check_raise_specific('#{func.name}', seqid, op, #{t.first.type}) do"
          o "  @handler.#{func.name}(*args)"
          o "end"

          o "return unless result"
        else
          o "result = @handler.#{func.name}(*args)"
        end

        if func.options == :oneway
          o "return result"
          outdent
          o "end"
          next
        end

        o "op.write_message_begin '#{func.name}', ::Thrift::MessageTypes::REPLY, seqid"
        o "op.write_struct_begin '#{func.name}_result'"

        ft = func.return_type

        if ft != "void"
          write_field ft, 'result', 0
        end

        o "op.write_field_stop"
        o "op.write_struct_end"
        o "op.write_message_end"
        o "op.trans.flush"
        o "return result"

        outdent
        o "end"
      end

      outdent
      o "end"
    end

    def process_service(serv)
      o "module #{serv.name}"
      indent
      o "class Client < Stark::Client"
      indent

      o "Functions = {}"
      serv.functions.each do |func|
        o "Functions[\"#{func.name}\"] = {"

        o "    :args => {"

        mapped_args = Array(func.arguments).map do |a|
          "#{a.index} => #{wire_type(a.type)}"
        end

        o "      #{mapped_args.join(', ')}"

        o "    }"
        o "  }"
      end

      serv.functions.each do |func|
        names = Array(func.arguments).map { |f| f.name }.join(", ")

        o "def #{func.name}(#{names})"
        indent
        o "op = @oprot"
        o "op.write_message_begin '#{func.name}', ::Thrift::MessageTypes::CALL, 0"
        o "op.write_struct_begin \"#{func.name}_args\""

        Array(func.arguments).each do |arg|
          write_field arg.type, arg.name, arg.index
        end

        o "op.write_field_stop"
        o "op.write_struct_end"
        o "op.write_message_end"
        o "op.trans.flush"

        if func.options == :oneway
          o "return"
          outdent
          o "end"
          next
        end

        o "ip = @iprot"
        o "_, mtype, _ = ip.read_message_begin"

        o "handle_exception mtype"

        o "ip.read_struct_begin"

        o "_, rtype, rid = ip.read_field_begin"

        if t = func.throws
          o "if rid == 1"
          o "  handle_throw #{t.first.type}"
          o "end"
        end

        o "fail unless rid == 0"

        o "result = nil"

        if func.return_type != "void"
          read_type func.return_type, "result"
          o "_, rtype, rid = ip.read_field_begin unless rtype == ::Thrift::Types::STOP"
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

      write_processor serv

      outdent
      o "end"
    end
  end

end

