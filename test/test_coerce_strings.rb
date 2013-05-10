require 'test/unit'

require 'stark'
require 'thrift'

require 'test/test_helper'

class TestCoerceStrings1 < Test::Unit::TestCase
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

class TestCoerceStrings2 < Test::Unit::TestCase
  IDL = "test/profile.thrift"
  SERVICE = "UserStorage"
  include TestHelper

  def setup
    setup_server
  end

  def test_coerce_string_to_int

    send_to_server do
      name = "add"
      @client_p.write_message_begin name, Thrift::MessageTypes::CALL, 0
      @client_p.write_struct_begin "#{name}_args"
      @client_p.write_field_begin "a", Thrift::Types::STRING, 1
      @client_p.write_string "1"
      @client_p.write_field_end
      @client_p.write_field_begin "b", Thrift::Types::STRING, 2
      @client_p.write_string "1"
      @client_p.write_field_end
      @client_p.write_field_stop
      @client_p.write_struct_end
      @client_p.write_message_end
      @client_p.trans.flush

      @client_p.read_message_begin
      @client_p.read_struct_begin
      _, _, fid = @client_p.read_field_begin
      assert_equal 0, fid
      assert_equal 2, @client_p.read_i32
      @client_p.read_field_end
      _, type, _ = @client_p.read_field_begin
      assert_equal type, Thrift::Types::STOP
      @client_p.read_struct_end
      @client_p.read_message_end
    end
  end

  def test_coerce_number_list_to_string_list
    send_to_server do
      name = "set_list"
      @client_p.write_message_begin name, Thrift::MessageTypes::CALL, 0
      @client_p.write_struct_begin "#{name}_args"
      @client_p.write_field_begin "l", Thrift::Types::LIST, 1
      @client_p.write_list_begin ::Thrift::Types::I32, 3
      @client_p.write_i32 1
      @client_p.write_i32 2
      @client_p.write_i32 3
      @client_p.write_list_end
      @client_p.write_field_end
      @client_p.write_field_stop
      @client_p.write_struct_end
      @client_p.write_message_end
      @client_p.trans.flush
    end

    assert_equal ["1", "2", "3"], @handler.last_list
  end
end
