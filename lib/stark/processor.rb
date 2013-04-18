module Stark
  class Processor
    def initialize(handler)
      @handler = handler
    end

    def process(iprot, oprot)
      name, type, seqid  = iprot.read_message_begin
      fail unless type == Thrift::MessageTypes::CALL

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
  end
end
