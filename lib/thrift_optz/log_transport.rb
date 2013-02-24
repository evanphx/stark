module ThriftOptz
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
end
