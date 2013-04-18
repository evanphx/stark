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
  end
end
