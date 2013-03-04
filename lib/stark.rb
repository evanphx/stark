require 'thrift'

module Stark
  VERSION = '0.6.1'

  def self.pipe_transport
    cr, cw = IO.pipe
    sr, sw = IO.pipe

    client_t = Thrift::IOStreamTransport.new sr, cw
    server_t = Thrift::IOStreamTransport.new cr, sw

    [client_t, server_t]
  end

  def self.materialize(file, namespace=Object)
    require 'stark/parser'
    require 'stark/ruby'
    require 'stringio'

    ast = Stark::Parser.ast File.read(file)

    stream = StringIO.new

    ruby = Stark::Ruby.new stream
    ruby.run ast

    if ENV['STARK_DEBUG']
      puts stream.string
    end

    namespace.module_eval stream.string
  end
end
