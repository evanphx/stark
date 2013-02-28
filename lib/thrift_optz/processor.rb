module ThriftOptz
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
        iprot.skip(Types::STRUCT)
        iprot.read_message_end
        x = ApplicationException.new(ApplicationException::UNKNOWN_METHOD, 'Unknown function '+name)
        oprot.write_message_begin(name, MessageTypes::EXCEPTION, seqid)
        x.write(oprot)
        oprot.write_message_end
        oprot.trans.flush
        false
      end
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
