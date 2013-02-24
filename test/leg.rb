require 'rubygems'
require 'thrift'

$: << "test/legacy_profile"

require 'user_storage'

f = File.read("test/new_client.rb")

eval "module New; #{f}; end"

cr, cw = IO.pipe
sr, sw = IO.pipe


class LogTransport < Thrift::BaseTransport
  def initialize(inner, prefix="log")
    @prefix = prefix
    @inner = inner
  end

  def log(name)
    puts "#{@prefix}: #{name}"
  end

  def open?; log :open?; @inner.open? end
  def read(sz); log :read; @inner.read(sz) end
  def write(buf); log :write; @inner.write(buf) end
  def close; log :close; @inner.close end
  def to_io; @inner.to_io end
end

client_t = Thrift::IOStreamTransport.new sr, cw

client_p = Thrift::BinaryProtocol.new LogTransport.new(client_t, "client")

client = New::UserStorage::Client.new client_p, client_p


server_t = Thrift::IOStreamTransport.new cr, sw
server_p = Thrift::BinaryProtocol.new LogTransport.new(server_t, "server")

class Handler
  def initialize
    @users = {}
  end

  def store(obj)
    p obj
    @users[obj.uid] = obj
  end

  def retrieve(id)
    @users[id]
  end
end

server = UserStorage::Processor.new Handler.new

Thread.abort_on_exception = true

st = Thread.new do
  server.process server_p, server_p
end

xuser = New::UserProfile.new 'uid' => 0, 'name' => 'root', 'blurb' => 'god'

client.store xuser

st.join

st = Thread.new do
  server.process server_p, server_p
end

obj = client.retrieve 0
p obj
