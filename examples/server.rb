require 'thrift'
require 'stark'

Stark.materialize "examples/health.thrift"

class Health::Handler

  def check
    Healthcheck.new('ok' => true, "message" => "OK")
  end

end

transport = Thrift::UNIXServerSocket.new '/tmp/health_sock'
processor = Health::Processor.new Health::Handler.new
server    = Thrift::SimpleServer.new processor, transport
server.serve

