module Stark
  class Struct
    def initialize(*fields)
      @fields = {}
      if fields.length == 1 && Hash === fields.first &&
          fields.first.keys.all? {|k| has_field? k }
        fields.first.each {|k,v| self[k] = v }
      else
        self.class::Fields.keys.each {|k| self[k] = fields.shift }
      end
    end

    def self.field_hash(fields = {})
      Hash.new {|h,k| Start::Field.new(k, nil, nil) }.update(fields)
    end

    def has_field?(field)
      self.class::Fields.keys.include?(field) ||
        self.class::Fields.values.detect {|f| f.name == field }
    end

    def [](field)
      case field
      when Fixnum
        @fields[self.class::Fields[field].name]
      when String
        @fields[field]
      when Symbol
        @fields[field.to_s]
      else
        raise TypeError, "invalid field index type: #{field.class}"
      end
    end

    def []=(field, val)
      case field
      when Fixnum
        name = self.class::Fields[field].name
        @fields[name] = val if name
      when String
        @fields[field] = val
      when Symbol
        @fields[field.to_s] = val
      else
        raise TypeError, "invalid field index type: #{field.class}"
      end
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
        field.write op, @fields[field.name] if @fields[field.name]
      end
    end

    def write(op)
      op.write_struct_begin self.class.name
      write_fields op
      op.write_field_stop
      op.write_struct_end
    end
  end
end
