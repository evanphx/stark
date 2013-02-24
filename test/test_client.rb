require 'test/unit'

require 'thrift_optz'

require 'rubygems'
require 'thrift'

$: << "test/legacy_profile"

require 'user_storage'

class TestClient < Test::Unit::TestCase
  def setup
    @client_t, @server_t = ThriftOptz.pipe_transport
    @client_p = Thrift::BinaryProtocol.new @client_t
    @server_p = Thrift::BinaryProtocol.new @server_t

    @n = Module.new
    ThriftOptz.materialize "test/profile.thrift", @n

    @client = @n::UserStorage::Client.new @client_p, @client_p
    @handler = Handler.new
    @server = UserStorage::Processor.new @handler
  end

  def teardown
    @client_t.close
    @server_t.close
  end

  class Handler
    def initialize
      @users = {}
      @last_map = nil
      @last_list = nil
    end

    attr_accessor :last_map, :last_list

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
  end

  def test_store_and_retrieve
    st = Thread.new do
      @server.process @server_p, @server_p
    end

    xuser = @n::UserProfile.new 'uid' => 0, 'name' => 'root', 'blurb' => 'god'

    @client.store xuser

    st.join

    st = Thread.new do
      @server.process @server_p, @server_p
    end

    obj = @client.retrieve 0

    st.join

    assert_equal 0, obj.uid
    assert_equal "root", obj.name
    assert_equal "god", obj.blurb
  end

  def test_set_map
    st = Thread.new do
      @server.process @server_p, @server_p
    end

    m = { "blah" => "foo", "a" => "b" }

    @client.set_map m

    st.join

    assert_equal "foo", @handler.last_map["blah"]
    assert_equal "b", @handler.last_map["a"]
  end

  def test_last_map
    st = Thread.new do
      @server.process @server_p, @server_p
    end

    @handler.last_map = { "blah" => "foo", "a" => "b" }

    m = @client.last_map

    st.join

    assert_equal "foo", m["blah"]
    assert_equal "b", m["a"]
  end

  def test_set_list
    st = Thread.new do
      @server.process @server_p, @server_p
    end

    m = [ "blah", "foo", "a", "b" ]

    @client.set_list m

    st.join

    assert_equal m, @handler.last_list
  end

  def test_last_list
    st = Thread.new do
      @server.process @server_p, @server_p
    end

    l = [ "blah", "foo", "a", "b" ]
    @handler.last_list = l

    begin
      assert_equal l, @client.last_list
    rescue Interrupt => e
      puts e.backtrace
    end

    st.join
  end

  def test_last_list_wrong_type
    st = Thread.new do
      @server.process @server_p, @server_p
    end

    begin
      assert_equal nil, @client.last_list
    rescue Interrupt => e
      puts e.backtrace
    end

    st.join
  end
end
