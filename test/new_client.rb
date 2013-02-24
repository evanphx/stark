require 'thrift_optz/client'
require 'thrift_optz/struct'
require 'thrift_optz/field'
require 'thrift_optz/converters'
class UserProfile < ThriftOptz::Struct
  Fields = {
    1 => ThriftOptz::Field.new(1, 'uid', ThriftOptz::Converters::I32),
    2 => ThriftOptz::Field.new(2, 'name', ThriftOptz::Converters::STRING),
    3 => ThriftOptz::Field.new(3, 'blurb', ThriftOptz::Converters::STRING),
    :count => 3
  }
end
module UserStorage
  class Client < ThriftOptz::Client
    Functions = {}
    Functions["store"] = {
        :args => {
          1 => ::Thrift::Types::STRUCT
        }
      }
    Functions["retrieve"] = {
        :args => {
          1 => ::Thrift::Types::I32
        }
      }
    def store(xuser)
      op = @oprot
      op.write_message_begin 'store', ::Thrift::MessageTypes::CALL, 0
      op.write_struct_begin "store_args"
      op.write_field_begin 'xuser', ::Thrift::Types::STRUCT, 1
      op.write_struct_begin 'UserProfile'
      op.write_field_begin 'uid', ::Thrift::Types::I32, 1
      op.write_i32 xuser.uid
      op.write_field_end
      op.write_field_begin 'name', ::Thrift::Types::STRING, 2
      op.write_string xuser.name
      op.write_field_end
      op.write_field_begin 'blurb', ::Thrift::Types::STRING, 3
      op.write_string xuser.blurb
      op.write_field_end
      op.write_field_stop
      op.write_struct_end
      op.write_field_end
      op.write_field_stop
      op.write_struct_end
      op.write_message_end
      op.trans.flush
      ip = @iprot
      fname, mtype, rseqid = ip.read_message_begin
      handle_exception mtype
      ip.read_struct_begin
      rname, rtype, rid = ip.read_field_begin
      result = nil
      fail if rtype != ::Thrift::Types::STOP
      ip.read_struct_end
      ip.read_message_end
      return result
    end
    def retrieve(xuid)
      op = @oprot
      op.write_message_begin 'retrieve', ::Thrift::MessageTypes::CALL, 0
      op.write_struct_begin "retrieve_args"
      op.write_field_begin 'xuid', ::Thrift::Types::I32, 1
      op.write_i32 xuid
      op.write_field_end
      op.write_field_stop
      op.write_struct_end
      op.write_message_end
      op.trans.flush
      ip = @iprot
      fname, mtype, rseqid = ip.read_message_begin
      handle_exception mtype
      ip.read_struct_begin
      rname, rtype, rid = ip.read_field_begin
      result = read_generic rtype, rid, UserProfile
      rname, rtype, rid = ip.read_field_begin
      fail if rtype != ::Thrift::Types::STOP
      ip.read_struct_end
      ip.read_message_end
      return result
    end
  end
end
