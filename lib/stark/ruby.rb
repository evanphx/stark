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
      o
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

    BUILTINS = %w!bool byte i16 i32 i64 double string void!

    def converter(t)
      if t.kind_of? Stark::Parser::AST::List
        "Stark::Converters::List.new(#{converter(t.value)})"
      elsif t.kind_of? Stark::Parser::AST::Set
        "Stark::Converters::Set.new(#{converter(t.value)})"
      elsif t.kind_of? Stark::Parser::AST::Map
        "Stark::Converters::Map.new(#{converter(t.key)}, #{converter(t.value)})"
      elsif BUILTINS.include? t.downcase
        "Stark::Converters::#{t.upcase}"
      elsif desc = @exceptions[t]
        "Stark::Converters::Exception.new(#{t})"
      elsif desc = @structs[t]
        "Stark::Converters::Struct.new(#{t})"
      elsif desc = @enums[t]
        "Stark::Converters::Enum.new(Enum_#{t})"
      else
        raise "Unknown type <#{t}>"
      end
    end

    def process_struct(str, include_to_a = false)
      @structs[str.name] = str

      o
      o "class #{str.name} < Stark::Struct"
      indent
      o "Fields = field_hash("
      indent
      fields = (str.fields || []).map do |f|
        c = converter f.type
        o "#{f.index} => Stark::Field.new(#{f.index}, '#{f.name}', #{c}),"
      end
      o ")"
      outdent

      (str.fields || []).each do |f|
        o "def #{f.name}; @fields['#{f.name}']; end"
      end

      if include_to_a
        o "def to_a"
        o "  #{(str.fields || []).map {|f| f.name }.inspect}.map {|n| @fields[n] }"
        o "end"
      end

      outdent
      o "end"
    end

    def process_exception(str)
      @exceptions[str.name] = str

      o
      o "class #{str.name} < Stark::Exception"
      indent

      str.name.clear; str.name.concat("Struct")
      process_struct(str)

      (str.fields || []).each do |f|
        o "def #{f.name}; @struct.#{f.name}; end"
      end

      outdent
      o "end"
    end

    def write_processor(serv)
      o
      o "class Processor < Stark::Processor"
      indent

      separate = false
      serv.functions.each do |func|
        o if separate
        separate = true

        o "def process_#{func.name}(seqid, ip, op)"
        indent

        o "args = Args_for_#{func.name}.new.read(ip).to_a"
        o "ip.read_message_end"

        o "result = Result_for_#{func.name}.new"
        if t = func.throws
          o "begin"
          o "  result[0] = @handler.#{func.name}(*args)"
          t.each do |tf|
            o "rescue #{tf.type} => e#{tf.index}"
            o "  result[#{tf.index}] = e#{tf.index}"
          end
          o "end"
        elsif func.return_type == "void"
          o "@handler.#{func.name}(*args)"
        else
          o "result[0] = @handler.#{func.name}(*args)"
        end

        if func.options == :oneway
          o "return result[0]"
          outdent
          o "end"
          next
        end

        o "op.write_message_begin '#{func.name}', ::Thrift::MessageTypes::REPLY, seqid"
        o "result.write(ip)"
        o "op.write_message_end"
        o "op.trans.flush"
        o "return result[0]"

        outdent
        o "end"
      end

      outdent
      o "end"
    end

    def write_client(serv)
      o
      o "class Client < Stark::Client"
      indent

      separate = false
      serv.functions.each do |func|
        names = Array(func.arguments).map { |f| f.name }.join(", ")
        o if separate
        separate = true

        o "def #{func.name}(#{names})"
        indent
        o "op = @oprot"
        o "op.write_message_begin '#{func.name}', ::Thrift::MessageTypes::CALL, 0"
        o "Args_for_#{func.name}.new(#{names}).write(op)"
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

        o "returnval = Result_for_#{func.name}.new.read(ip)"

        o "ip.read_message_end"

        if t = func.throws
          t.each do |tf|
            o "raise returnval[#{tf.index}] if returnval[#{tf.index}]"
          end
        end

        if func.return_type != "void"
          o "returnval.result"
        else
          o "nil"
        end

        outdent

        o "end"
      end

      outdent
      o "end"
    end

    def process_service(serv)
      o
      o "module #{serv.name}"
      indent
      serv.functions.each do |func|
        process_struct(Stark::Parser::AST::Struct.new("struct", "Args_for_#{func.name}", func.arguments), true)
        result_fields = [Stark::Parser::AST::Field.new(0, func.return_type, "result", nil, nil)]
        result_fields += func.throws if func.throws
        process_struct(Stark::Parser::AST::Struct.new("struct", "Result_for_#{func.name}", result_fields))
      end

      write_client serv
      write_processor serv

      outdent
      o "end"
    end
  end

end

