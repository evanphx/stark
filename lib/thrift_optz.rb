require 'thrift'

module ThriftOptz
  VERSION = '1.0.0'

  def self.pipe_transport
    cr, cw = IO.pipe
    sr, sw = IO.pipe

    client_t = Thrift::IOStreamTransport.new sr, cw
    server_t = Thrift::IOStreamTransport.new cr, sw

    [client_t, server_t]
  end

  def self.materialize(file, namespace=Object)
    require 'thrift_optz/parser'
    require 'thrift_optz/ruby'
    require 'stringio'

    data = File.read file

    tg = ThriftOptz::Parser.new data

    unless tg.parse
      tg.raise_error
    end

    stream = StringIO.new

    ruby = ThriftOptz::Ruby.new stream

    tg.result.each { |i| i.accept ruby }

    namespace.module_eval stream.string
  end
end
