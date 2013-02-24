module ThriftOptz
  class Client
    def initialize(iprot, oprot)
      @iprot = iprot
      @oprot = oprot
    end

    def handle_exception(mtype)
      if mtype == Thrift::MessageTypes::EXCEPTION
        x = Thrift::ApplicationException.new
        x.read(@iprot)
        @iprot.read_message_end
        raise x
      end
    end

    def read_generic(type, id, cls)
      ip = @iprot

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
