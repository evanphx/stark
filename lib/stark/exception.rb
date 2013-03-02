module Stark
  class Exception < RuntimeError
    def initialize(struct)
      super "A remote exception occurred"

      if struct.kind_of? Hash
        @struct = self.class::Struct.new(struct)
      else
        @struct = struct
      end
    end

    attr_reader :struct
  end
end
