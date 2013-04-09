require 'thrift'
require 'health'

class Health::Handler

  def check
    Healthcheck.new('ok' => true, "message" => "OK")
  end

end

transport = Thrift::UNIXServerSocket.new '/tmp/health_sock'
processor = Health::Processor.new Health::Handler.new
server    = Thrift::SimpleServer.new processor, transport
server.serve

