module ThriftOptz
  class Struct
    def initialize(fields={})
      @fields = fields
    end

    def set_from_index(type, idx, ip)
      info = self.class::Fields[idx]
      return unless info

      return unless info.type == type

      @fields[info.name] = info.read(ip)
    end

    def method_missing(meth, *args)
      if val = @fields[meth.to_s]
        return val
      end

      super
    end
  end
end
