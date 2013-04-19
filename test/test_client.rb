require 'test/unit'

require 'stark'

require 'rubygems'
require 'thrift'

$: << "test/legacy_profile"

require 'user_storage'

class TestClient < Test::Unit::TestCase
  def setup
    @client_t, @server_t = Stark.pipe_transport
    @client_p = Thrift::BinaryProtocol.new @client_t
    @server_p = Thrift::BinaryProtocol.new @server_t

    @n = Module.new
    Stark.materialize "test/profile.thrift", @n

    @client = @n::UserStorage::Client.new @client_p, @client_p
    @handler = Handler.new(@n)
    @server = UserStorage::Processor.new @handler
  end

  def teardown
    @client_t.close
    @server_t.close
  end

  class Handler
    def initialize(n)
      @users = {}
      @last_map = nil
      @last_list = nil
      @last_status = nil
      @n = n
      @user_status = nil
      @user_relationship = nil
    end

    attr_accessor :last_map, :last_list, :last_status, :user_status

    def store(obj)
      @users[obj.uid] = obj
    end

    def retrieve(id)
      @users[id]
    end

    def set_map(m)
      @last_map = m
    end

    def set_list(l)
      @last_list = l
    end

    def set_status(s)
      @last_status = s
    end

    def volume_up
      raise RockTooHard.new(:volume => 11)
    end

    def make_bitcoins
      sleep 2
    end

    def add(a,b)
      a + b
    end

    def set_user_status(s)
      @user_status = s
    end

    attr_accessor :user_relationship
    def set_user_relationship(rel)
      @user_relationship = rel
    end

    attr_accessor :user_friends
    def set_user_friends(fr)
      @user_friends = fr
    end
  end

  def send_to_server
    st = Thread.new do
      @server.process @server_p, @server_p
    end
    yield
  ensure
    st.join
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

      begin
        assert_equal l, @client.last_list
      rescue Interrupt => e
        puts e.backtrace
      end
    end
  end

  def test_last_list_is_nil
    send_to_server do
      begin
        assert_equal nil, @client.last_list
      rescue Interrupt => e
        puts e.backtrace
      end
    end
  end

  def test_enum
    send_to_server do
      @client.set_status :ON
    end

    assert_equal 0, @handler.last_status
  end

  def test_enum_recv
    send_to_server do
      @handler.last_status = 0

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
      prof = UserProfile.new 'uid' => 0, 'name' => 'root', 'blurb' => 'god'
      stat = UserStatus.new 'profile' => prof, 'active' => true

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
      stat = UserRelationship.new 'user' => 0, 'status' => 4

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
      assert_equal 4, rel.status
    end
  end

  def test_read_list_in_struct
    send_to_server do
      stat = UserFriends.new 'user' => 0, 'friends' => [4,8,47]

      @handler.user_friends = stat

      rel = @client.user_friends

      assert_equal 0, rel.user
      assert_equal [4,8,47], rel.friends
    end
  end

  def test_write_list_in_struct
    send_to_server do
      stat = @n::UserFriends.new 'user' => 0, 'friends' => [4,8,47]

      @client.set_user_friends stat

      rel = @handler.user_friends

      assert_equal 0, rel.user
      assert_equal [4,8,47], rel.friends
    end
  end
end
