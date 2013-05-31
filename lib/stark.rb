require 'thrift'
require 'logger'

module Stark
  VERSION = '0.8.0'

  def self.logger
    @logger ||= ::Logger.new($stdout)
  end

  def self.logger=(logger)
    @logger = logger
  end

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

    begin
      contents = Stark::Parser.read_file(file)
      ast = Stark::Parser.ast contents
    rescue => e
      raise e, e.message + " while processing #{file} -\n#{e.backtrace.join("\n")}"
    end

    stream = StringIO.new

    ruby = Stark::Ruby.new stream
    ruby.run ast

    if ENV['STARK_DEBUG']
      puts stream.string
    end

    namespace.module_eval stream.string
  end
end
