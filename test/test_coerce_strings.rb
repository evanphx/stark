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

  def test_coerce_strings_on_write_parameter
    @handler.store @n::UserProfile.new(:uid => 123, :name => "Gob")

    profile = send_to_server do
      @client.retrieve "123"
    end

    assert profile
    assert_equal "Gob", profile.name
  end

  def test_coerce_strings_on_write_struct_field
    send_to_server do
      @client.set_user_friends @n::UserFriends.new(:user => "123")
    end

    assert @handler.user_friends
    assert_equal 123, @handler.user_friends.user
  end

  def test_coercion_fails_on_write_with_incompatible_types
    assert_raises TypeError do
      @client.store "user_profile"
    end
  end

  class BadTypesHandler
    def initialize(n)
      @n = n
    end

    def retrieve(uid)
      @n::UserProfile.new(:uid => "123", :name => 123)
    end

    def volume_up
      "11"
    end
  end

  def test_coerce_strings_on_processor_write_struct_field
    set_handler BadTypesHandler.new(@n)

    profile = send_to_server do
      @client.retrieve 123
    end

    assert profile
    assert_equal "123", profile.name
  end

  def test_coerce_strings_on_processor_write_return_value
    set_handler BadTypesHandler.new(@n)

    vol = send_to_server do
      @client.volume_up
    end

    assert vol
    assert_equal 11, vol
  end

  def test_coercion_fails_on_processor_write_with_incompatible_types
    set_handler Object.new.tap {|h|
      def h.retrieve(uid)
        "user_profile"
      end
    }

    assert_raises Thrift::ApplicationException do
      send_to_server do
        @client.retrieve 123
      end
    end
  end

end
