require 'test/unit'

require 'stark'

require 'rubygems'
require 'thrift'

require 'test_helper'

class TestServer < Test::Unit::TestCase
  include TestHelper

  def setup
    setup_server
  end

  def test_store_and_retrieve
    send_to_server do
      xuser = @n::UserProfile.new 'uid' => 0, 'name' => 'root', 'blurb' => 'god'

      @client.store xuser
    end

    obj = send_to_server do
      @client.retrieve 0
    end

    assert_equal 0, obj.uid
    assert_equal "root", obj.name
    assert_equal "god", obj.blurb
  end

  def test_set_map
    send_to_server do
      m = { "blah" => "foo", "a" => "b" }

      @client.set_map m
    end

    assert_equal "foo", @handler.last_map["blah"]
    assert_equal "b", @handler.last_map["a"]
  end

  def test_last_map
    m = send_to_server do
      @handler.last_map = { "blah" => "foo", "a" => "b" }

      @client.last_map
    end

    assert_equal "foo", m["blah"]
    assert_equal "b", m["a"]
  end

  def test_set_list
    m = [ "blah", "foo", "a", "b" ]
    send_to_server do

      @client.set_list m
    end

    assert_equal m, @handler.last_list
  end

  def test_last_list
    send_to_server do
      l = [ "blah", "foo", "a", "b" ]
      @handler.last_list = l

      assert_equal l, @client.last_list
    end
  end

  def test_last_list_is_nil
    send_to_server do
      assert_equal [], @client.last_list
    end
  end

  def test_enum
    send_to_server do
      @client.set_status :ON
    end

    assert_equal :ON, @handler.last_status
  end

  def test_enum_recv
    send_to_server do
      @handler.last_status = :ON

      assert_equal :ON, @client.last_status
    end
  end

  def test_throw
    e = send_to_server do
      assert_raises @n::RockTooHard do
        @client.volume_up
      end
    end

    assert_equal 11, e.volume
  end

  def test_oneway
    send_to_server do
      t = Time.now

      Timeout.timeout 3 do
        assert_equal nil, @client.make_bitcoins
      end

      assert Time.now - t < 0.1
    end
  end

  def test_2args
    send_to_server do
      assert_equal 7, @client.add(3, 4)
    end
  end

  def test_read_struct_in_a_struct
    send_to_server do
      prof = @n::UserProfile.new 'uid' => 0, 'name' => 'root', 'blurb' => 'god'
      stat = @n::UserStatus.new 'profile' => prof, 'active' => true

      @handler.user_status = stat

      status = @client.user_status

      assert_equal true, status.active

      prof = status.profile

      assert_equal 0, prof.uid
      assert_equal "root", prof.name
      assert_equal "god", prof.blurb
    end
  end

  def test_write_struct_in_a_struct
    send_to_server do
      prof = @n::UserProfile.new 'uid' => 0, 'name' => 'root', 'blurb' => 'god'
      stat = @n::UserStatus.new 'profile' => prof, 'active' => true

      @client.set_user_status stat

      status = @handler.user_status

      assert_equal true, status.active

      prof = status.profile

      assert_equal 0, prof.uid
      assert_equal "root", prof.name
      assert_equal "god", prof.blurb
    end
  end

  def test_read_enum_in_struct
    send_to_server do
      stat = @n::UserRelationship.new 'user' => 0, 'status' => :ITS_COMPLICATED

      @handler.user_relationship = stat

      rel = @client.user_relationship

      assert_equal 0, rel.user
      assert_equal :ITS_COMPLICATED, rel.status
    end
  end

  def test_write_enum_in_struct
    send_to_server do

      stat = @n::UserRelationship.new 'user' => 0, 'status' => :ITS_COMPLICATED

      @client.set_user_relationship stat

      rel = @handler.user_relationship

      assert_equal 0, rel.user
      assert_equal :ITS_COMPLICATED, rel.status
    end
  end

  def test_exception_raised
    @server = @n::UserStorage::Processor.new @handler

  end
end
