require 'stark/converters'

module Stark
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

    def write(op, val)
      op.write_field_begin @name, type, @index
      @converter.write op, val
      op.write_field_end
    end
  end
end
