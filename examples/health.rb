require 'stark/client'
require 'stark/struct'
require 'stark/field'
require 'stark/converters'
require 'stark/processor'
require 'stark/exception'
class Healthcheck < Stark::Struct
  Fields = {
       1 => Stark::Field.new(1, 'ok', Stark::Converters::BOOL), 2 => Stark::Field.new(2, 'message', Stark::Converters::STRING)
  }
  def ok; @fields['ok']; end
  def message; @fields['message']; end
end
module Health
  class Client < Stark::Client
    Functions = {}
    Functions["check"] = {
        :args => {
          
        }
      }
    def check()
      op = @oprot
      op.write_message_begin 'check', ::Thrift::MessageTypes::CALL, 0
      op.write_struct_begin "check_args"
      op.write_field_stop
      op.write_struct_end
      op.write_message_end
      op.trans.flush
      ip = @iprot
      _, mtype, _ = ip.read_message_begin
      handle_exception mtype
      ip.read_struct_begin
      _, rtype, rid = ip.read_field_begin
      fail unless rid == 0
      result = nil
      if rtype != ::Thrift::Types::STRUCT
        handle_unexpected rtype
      else
        result = read_generic rtype, rid, Healthcheck
      end
      _, rtype, rid = ip.read_field_begin unless rtype == ::Thrift::Types::STOP
      fail if rtype != ::Thrift::Types::STOP
      ip.read_struct_end
      ip.read_message_end
      return result
    end
  end
  class Processor < Stark::Processor
    def process_check(seqid, ip, op)
      ip.read_struct_begin
      args = Array.new(0)
      _, rtype, _ = ip.read_field_begin
      fail unless rtype == ::Thrift::Types::STOP
      ip.read_struct_end
      ip.read_message_end
      result = @handler.check(*args)
      op.write_message_begin 'check', ::Thrift::MessageTypes::REPLY, seqid
      op.write_struct_begin 'check_result'
      op.write_field_begin 'result', ::Thrift::Types::STRUCT, 0
      op.write_struct_begin 'Healthcheck'
      ok = result.ok
      op.write_field_begin 'ok', ::Thrift::Types::BOOL, 1
      op.write_bool ok
      op.write_field_end
      message = result.message
      op.write_field_begin 'message', ::Thrift::Types::STRING, 2
      op.write_string message
      op.write_field_end
      op.write_field_stop
      op.write_struct_end
      op.write_field_end
      op.write_field_stop
      op.write_struct_end
      op.write_message_end
      op.trans.flush
      return result
    end
  end
end
