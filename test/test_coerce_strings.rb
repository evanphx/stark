require 'test/unit'

require 'stark'
require 'thrift'

require 'test/test_helper'

class TestCoerceStrings < Test::Unit::TestCase
  IDL = "test/ThriftSpec.thrift"
  SERVICE = "SpecNamespace::NonblockingService"
  include TestHelper

  class Handler
    def sleep_value
      @sleep
    end

    def sleep(sec)
      @sleep = sec
    end
  end

  def setup
    @handler = Handler.new
    setup_server @handler
  end

  def test_coerce_string_to_double

    send_to_server do
      name = "sleep"
      @client_p.write_message_begin name, Thrift::MessageTypes::CALL, 0
      @client_p.write_struct_begin "#{name}_args"
      @client_p.write_field_begin "seconds", Thrift::Types::STRING, 1
      @client_p.write_string "1.5"
      @client_p.write_field_end
      @client_p.write_field_stop
      @client_p.write_struct_end
      @client_p.write_message_end
      @client_p.trans.flush

      @client_p.read_message_begin
      @client_p.skip Thrift::Types::STRUCT
      @client_p.read_message_end
    end

    assert_equal 1.5, @handler.sleep_value
  end
end
