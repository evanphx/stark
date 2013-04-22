require 'stark/protocol_helpers'

module Stark
  class Processor
    include ProtocolHelpers

    def initialize(handler)
      @handler = handler
    end

    def process(iprot, oprot)
      name, type, seqid  = iprot.read_message_begin
      fail unless type == Thrift::MessageTypes::CALL

      x = nil
      if respond_to?("process_#{name}")
        send("process_#{name}", seqid, iprot, oprot)
        true
      else
        iprot.skip(::Thrift::Types::STRUCT)
        iprot.read_message_end
        x = ::Thrift::ApplicationException.new(Thrift::ApplicationException::UNKNOWN_METHOD, 'Unknown function '+name)
        false
      end
    rescue ::Exception => e
      Stark.logger.error "#{self.class.name}#process_#{name}: #{e.message}\n  " + e.backtrace.join("\n  ")
      x = Thrift::ApplicationException.new(Thrift::ApplicationException::INTERNAL_ERROR, e.message)
      false
    ensure
      if x
        oprot.write_message_begin(name, ::Thrift::MessageTypes::EXCEPTION, seqid)
        x.write(oprot)
        oprot.write_message_end
        oprot.trans.flush
      end
    end
  end
end
