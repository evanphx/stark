module Stark
  class Struct
    def initialize(fields={})
      fields.each do |k,v|
        send(:"#{k}=", v) if respond_to?(:"#{k}=")
      end
    end

    def [](*args)
      values = []
      args.each do |a|
        case a
        when Fixnum
          n = self.class.fields[a]
          values << (n ? send(n) : nil)
        when Range
          values += self[*a.to_a]
        when String, Symbol
          values << send(a)
        end
      end
      values = values.first if values.size == 1
      values
    end

    def to_hash
      {}.tap do |hash|
        self.class.fields.each do |idx,name|
          v = send name
          case v
          when Array
            hash[name] = v.map(&:to_hash)
          else
            hash[name] = v if v
          end
        end
      end
    end

    def self.fields
      @fields ||= {}
    end

    def self.attr_accessor(*attrs)
      attrs.each do |a|
        n = field_number
        fields[n] = a
        self.field_number n + 1
      end
      super
    end

    def self.field_number(n = nil)
      @field_number = n if n
      @field_number ||= 1
    end
  end
end
