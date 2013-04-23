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
      o "require 'stark/processor'"
      o "require 'stark/struct'"
      o "require 'stark/exception'"
    end

    def run(ast)
      ast.each { |a| a.accept self }
      close
    end

    def close
      write_protocol
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
      o
      o "module #{@namespace}"
      indent
    end

    def process_include(inc)
      raise NotImplementedError, "include not implemented"
    end

    def process_enum(enum)
      @enums[enum.name] = enum
      e = "Enum_#{enum.name}"
      o "#{e} = Hash.new { |h,k| p [:bad, k]; h[k] = -1 }"
      idx = 0
      enum.values.each do |f|
        o "#{e}[#{idx}] = :'#{f}'"
        o "#{e}[:'#{f}'] = #{idx}"
        idx += 1
      end
    end

    def write_field_declarations(fields)
      max_field_len = fields.inject(0) {|max,f| f.name.length > max ? f.name.length : max }
      max_index_len = fields.inject(0) {|max,f| f.index.to_s.length > max ? f.index.to_s.length : max }

      fields.each do |f|
        o("attr_accessor :%-*s  # %*s: %s" % [max_field_len, f.name, max_index_len, f.index, object_type(f.type)])
      end
    end

    def process_struct(str)
      @structs[str.name] = str

      o
      o "class #{str.name} < Stark::Struct"
      indent
      write_field_declarations str.fields
      outdent
      o "end"
    end

    BUILTINS = %w!bool byte i16 i32 i64 double string!

    def process_exception(str)
      @exceptions[str.name] = str

      o
      o "class #{str.name} < Stark::Exception"
      indent
      write_field_declarations str.fields
      outdent
      o "end"
    end

    def o(str = nil)
      @stream.print(" " * @indent) if str
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
      return "::Thrift::Types::STRUCT" if @structs[t] || @exceptions[t]
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
      case t
      when Stark::Parser::AST::Map
        "map<#{object_type(t.key)},#{object_type(t.value)}>"
      when Stark::Parser::AST::List
        "list<#{object_type(t.value)}>"
      when Stark::Parser::AST::Set
        "set<#{object_type(t.value)}>"
      else
        t
      end
    end

    def read_func(t)
      ReadFunc[t] || raise("unknown type - #{t}")
    end

    def write_func(t)
      WriteFunc[t] || raise("unknown type - #{t}")
    end

    def read_type(t, lhs, found_type = 'rtype')
      o "#{lhs} = expect ip, #{wire_type(t)}, #{found_type} do"
      indent
      if desc = @structs[t]
        o "read_#{desc.name}(ip)"
      elsif desc = @enums[t]
        o "Enum_#{desc.name}[ip.read_i32]"
      elsif t.kind_of? Stark::Parser::AST::Map
        o "expect_map ip, #{wire_type(t.key)}, #{wire_type(t.value)} do |kt,vt,size|"
        indent
        o   "{}.tap do |_hash|"
        indent
        o     "size.times do"
        indent
        read_type(t.key, "k", "kt")
        read_type(t.value, "v", "vt")
        o       "_hash[k] = v"
        outdent
        o     "end"
        outdent
        o   "end"
        outdent
        o "end"
      elsif t.kind_of? Stark::Parser::AST::List
        o "expect_list ip, #{wire_type(t.value)} do |vt,size|"
        indent
        o   "Array.new(size) do"
        indent
        read_type t.value, "_elem", "vt"
        outdent
        o   "end"
        outdent
        o "end"
      elsif t.kind_of? Stark::Parser::AST::Set
        o "expect_set ip, #{wire_type(t.value)} do |vt,size|"
        indent
        o   "_arr = Array.new(size) do"
        indent
        read_type t.value, "element", "vt"
        o     "element"
        outdent
        o   "end"
        o   "::Set.new(_arr)"
        outdent
        o "end"
      else
        o "ip.#{read_func(t)}"
      end
      outdent
      o "end"
    end

    def write_type(ft, name)
      if desc = (@structs[ft] || @exceptions[ft])
        o "write_#{desc.name} op, #{name}"
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
        o "#{name} = Set.new(#{name})"
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

    def write_processor(serv)
      o "class Processor < Stark::Processor"
      indent
      o "include Protocol"

      serv.functions.each do |func|
        o
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
          o "begin"
          indent
          o "result = @handler.#{func.name}(*args)"
          outdent
          t.each do |ex|
            o "rescue #{ex.type} => ex#{ex.index}"
            indent
            o   "op.write_message_begin '#{func.name}', ::Thrift::MessageTypes::REPLY, seqid"
            o   "op.write_struct_begin '#{func.name}_result'"
            write_field ex.type, "ex#{ex.index}", ex.index
            o   "op.write_field_stop"
            o   "op.write_struct_end"
            o   "op.write_message_end"
            o   "op.trans.flush"
            o   "return"
            outdent
          end
          o "end"
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

    def write_protocol
      o
      o "module Protocol"
      indent
      @structs.merge(@exceptions).each do |name, struct|
        o
        o "def read_#{name}(ip)"
        indent
        o "obj = #{name}.new"
        o "ip.read_struct_begin"

        o "while true"
        o "  _, ftype, fid = ip.read_field_begin"
        o "  break if ftype == ::Thrift::Types::STOP"

        o "  case fid"
        struct.fields.each do |f|
          o "  when #{f.index}"
          indent; indent
          read_type f.type, "obj.#{f.name}", 'ftype'
          outdent; outdent
        end
        o "  else"
        o "    ip.skip ftype"
        o "  end"
        o "  ip.read_field_end"
        o "end"

        o "ip.read_struct_end"
        o "obj"
        outdent
        o "end"
        o
        o "def write_#{name}(op, str)"
        indent
        o "op.write_struct_begin '#{name}'"

        struct.fields.each do |f|
          o "if #{f.name} = str.#{f.name}"
          indent
          write_field f.type, f.name, f.index
          outdent
          o "end"
        end

        o "op.write_field_stop"
        o "op.write_struct_end"
        outdent
        o "end"
      end
      outdent
      o "end"
    end

    def write_client(serv)
      o "class Client < Stark::Client"
      indent
      o "include Protocol"

      serv.functions.each do |func|
        names = Array(func.arguments).map { |f| f.name }.join(", ")

        o
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
          o "case rid"
          t.each do |ex|
            o "when #{ex.index}"
            o "  _ex = read_#{ex.type}(ip)"
            o "  ip.read_field_end"
            o "  _, rtype, _ = ip.read_field_begin"
            o "  fail if rtype != ::Thrift::Types::STOP"
            o "  ip.read_struct_end"
            o "  ip.read_message_end"
            o "  raise _ex"
          end
          o "end"
        end

        o "fail unless rid == 0"

        o "result = nil"

        if func.return_type != "void"
          read_type func.return_type, "result"
          o "ip.read_field_end"
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
    end

    def process_service(serv)
      unless @protocol_declared
        o
        o "module Protocol; end"
        @protocol_declared = true
      end

      o
      o "module #{serv.name}"
      indent

      write_client serv
      o
      write_processor serv

      outdent
      o "end"
    end
  end

end

