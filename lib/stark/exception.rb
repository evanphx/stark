module Stark
  class Exception < RuntimeError
    def initialize(fields_or_msg = nil)
      case fields_or_msg
      when Hash
        fields_or_msg.each do |k,v|
          send(:"#{k}=", v) if respond_to?(:"#{k}=")
        end
      when nil
        fields_or_msg = "A remote exception occurred"
      end
      super
    end
  end
end
