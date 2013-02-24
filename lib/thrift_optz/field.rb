require 'thrift_optz/converters'

module ThriftOptz
  class Field
    def initialize(idx, name, converter)
      @index = idx
      @name = name
      @converter = converter
    end

    attr_reader :index, :name, :converter

    def type
      @converter.type
    end

    def read(ip)
      @converter.read ip
    end
  end
end
