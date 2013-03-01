module Stark
  class Exception < RuntimeError
    def initialize(struct)
      super "A remote exception occurred"

      @struct = struct
    end

    attr_reader :struct
  end
end
