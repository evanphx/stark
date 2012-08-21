require 'thrift_optz/ast'

module ThriftOptz
  class Ruby
    def initialize
      @namespace = nil
    end

    def process_namespace(ns)
      @namespace = ns.namespace if ns.lang == "rb"
    end

    def process_include(inc)
    end

    def process_struct(str)
    end

    def process_service(serv)
      puts "module #{serv.name}"
      puts "class Client"

      serv.functions.each do |func|
        names = func.arguments.map { |f| f.name }.join(", ")

        puts "def #{func.name}(#{names})"
        puts "  op = @oprot"
        puts "  op.write_message_begin '#{func.name}', ::Thrift::MessageTypes::CALL, 0"
        puts "  op.write_struct_begin \"#{func.name}_args\""

        func.arguments.each do |arg|
          puts "  op.write_field_begin '#{arg.name}', ::Thrift::Types::I32, #{arg.index}"
          puts "  op.write_i32 #{arg.name}"
          puts "  op.write_field_end"
        end

        puts "  op.write_field_stop"
        puts "  op.write_struct_end"
        puts "  op.write_message_end"
        puts "  op.trans.flush"

        puts "  ip = @iprot"
        puts "  fname, mtype, rseqid = ip.read_message_begin"
        puts "  handle_exception mtype"

        puts "  ip.read_struct_begin"
        puts "  rname, rtype, rid = ip.read_field_begin"
        puts "  result = ip.read_i32"
        puts "  rname, rtype, rid = ip.read_field_begin"
        puts "  fail if rtype != ::Thrift::Types::STOP"
        puts "  ip.read_field_end"

        puts "  ip.read_struct_end"
        puts "  ip.read_message_end"
        puts "  return result"

        puts "end"
      end

      puts "end"
      puts "end"
    end
  end

end

