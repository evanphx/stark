require 'stark'

module Stark
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

    def handle_throw(cls)
      ip = @iprot

      obj = cls::Struct.new

      ip.read_struct_begin

      while true
        _, ftype, fid = ip.read_field_begin
        break if ftype == ::Thrift::Types::STOP

        obj.set_from_index ftype, fid, ip

        ip.read_field_end
      end

      ip.read_struct_end

      ip.read_message_end

      raise cls.new(obj)
    end

    def handle_unexpected(rtype)
      return if rtype == ::Thrift::Types::STOP
      @iprot.skip(rtype)
    end

    def handle_bad_list(rtype, size)
      size.times { @iprot.skip(rtype) }
    end

    def handle_bad_map(key, value, size)
      size.times do
        @iprot.skip(key)
        @iprot.skip(value)
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
