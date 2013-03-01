module Stark
  class Struct
    def initialize(fields={})
      @fields = fields
    end

    def set_from_index(type, idx, ip)
      info = self.class::Fields[idx]
      return unless info

      if info.type == type
        @fields[info.name] = info.read(ip)
      else
        ip.skip type
      end
    end
  end
end
