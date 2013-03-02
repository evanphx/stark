module Stark
  class Processor
    def initialize(handler)
      @handler = handler
    end

    def process(iprot, oprot)
      name, type, seqid  = iprot.read_message_begin
      if respond_to?("process_#{name}")
        send("process_#{name}", seqid, iprot, oprot)
        true
      else
        iprot.skip(::Thrift::Types::STRUCT)
        iprot.read_message_end
        x = ::Thrift::ApplicationException.new(Thrift::ApplicationException::UNKNOWN_METHOD, 'Unknown function '+name)
        oprot.write_message_begin(name, ::Thrift::MessageTypes::EXCEPTION, seqid)
        x.write(oprot)
        oprot.write_message_end
        oprot.trans.flush
        false
      end
    end

    def check_raise_specific(name, seqid, op, c)
      begin
        yield
      rescue c => e
        op.write_message_begin name, ::Thrift::MessageTypes::REPLY, seqid
        op.write_struct_begin 'result_struct'

        op.write_field_begin 'result', ::Thrift::Types::STRUCT, 1
        op.write_struct_begin c.class.name
        e.struct.write_fields op
        op.write_field_end
        op.write_field_stop
        op.write_struct_end

        op.write_field_end
        op.write_field_stop
        op.write_struct_end

        op.write_message_end
        op.trans.flush

        nil
      end
    end

    def hash_cast(obj)
      return obj if obj.kind_of? Hash
      return obj.to_h if obj.respond_to? :to_h

      raise TypeError, "Unable to convert #{obj.class} to Hash"
    end

    def read_struct(ip, type, id, cls)
      obj = cls.new

      ip.read_struct_begin

      while true
        _, ftype, fid = ip.read_field_begin
        break if ftype == ::Thrift::Types::STOP

        obj.set_from_index ftype, fid, ip

        ip.read_field_end
      end

      ip.read_struct_end

      obj
    end
  end
end
