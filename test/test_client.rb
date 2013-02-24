require 'test/unit'

require 'thrift_optz'

require 'rubygems'
require 'thrift'

$: << "test/legacy_profile"

require 'user_storage'

Thread.abort_on_exception = true

class TestClient < Test::Unit::TestCase
  def setup
    @client_t, @server_t = ThriftOptz.pipe_transport
    @client_p = Thrift::BinaryProtocol.new @client_t
    @server_p = Thrift::BinaryProtocol.new @server_t

    @n = Module.new
    ThriftOptz.materialize "test/profile.thrift", @n

    @client = @n::UserStorage::Client.new @client_p, @client_p
    @server = UserStorage::Processor.new Handler.new
  end

  def teardown
    @client_t.close
    @server_t.close
  end

  class Handler
    def initialize
      @users = {}
    end

    def store(obj)
      @users[obj.uid] = obj
    end

    def retrieve(id)
      @users[id]
    end
  end

  def test_client
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
end
