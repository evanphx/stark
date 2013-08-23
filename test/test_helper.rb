module TestHelper
  def setup_shared
    @client_t, @server_t = Stark.pipe_transport
    @client_p = Thrift::BinaryProtocol.new @client_t
    @server_p = Thrift::BinaryProtocol.new @server_t

    @n = Module.new
    Stark.materialize self.class::IDL, @n
    @s = @n.module_eval self.class::SERVICE
    @prev_logger = Stark.logger
    @log_stream = StringIO.new
    Stark.logger = Logger.new @log_stream
  end

  def setup_client
    setup_shared
    @client = @n::UserStorage::Client.new @client_p, @client_p
    @handler = Handler.new(Object)
    @server = UserStorage::Processor.new @handler
  end

  def setup_server(handler = nil)
    setup_shared
    @client = @s::Client.new @client_p, @client_p
    set_handler handler
  end

  def set_handler(handler = nil)
    @handler = handler || Handler.new(@n)
    @server = @s::Processor.new @handler
  end

  def teardown
    print @log_stream.string unless passed?
    Stark.logger = @prev_logger
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
      @user_friends = nil
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
      raise @n::RockTooHard.new(:volume => 11)
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
  rescue => e
    st = nil
    raise e
  ensure
    st.value if st
  end

end
