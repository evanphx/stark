module Stark
  class Struct
    def initialize(fields={})
      fields.each do |k,v|
        send(:"#{k}=", v) if respond_to?(:"#{k}=")
      end
    end
  end
end
