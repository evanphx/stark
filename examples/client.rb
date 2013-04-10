require 'thrift'
require 'stark'

Stark.materialize "examples/health.thrift"

socket    = Thrift::UNIXSocket.new('/tmp/health_sock').tap { |s| s.open }
transport = Thrift::IOStreamTransport.new socket.to_io, socket.to_io
proto     = Thrift::BinaryProtocol.new transport
client    = Health::Client.new proto, proto

result = client.check
p [result.ok, result.message]

