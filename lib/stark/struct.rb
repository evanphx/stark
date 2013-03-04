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

    def read(ip)
      ip.read_struct_begin

      while true
        _, ftype, fid = ip.read_field_begin
        break if ftype == ::Thrift::Types::STOP

        set_from_index ftype, fid, ip

        ip.read_field_end
      end

      ip.read_struct_end

      self
    end

    def write_fields(op)
      self.class::Fields.each do |idx, field|
        next if idx == :count
        field.write op, @fields[field.name]
      end
    end
  end
end
