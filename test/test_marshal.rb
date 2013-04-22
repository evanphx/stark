require 'test/unit'

require 'stark'
require 'thrift'

require 'test/test_helper'

class TestMarshal < Test::Unit::TestCase
  IDL = "test/types.thrift"
  SERVICE = "Types"
  include TestHelper

  class Handler
    def initialize(n, at = nil, err = nil)
      @n = n
      @at = at || @n::AllTypes.new
      @err = err
    end

    def get_all_types
      @at
    end

    def set_all_types(at)
      @at = at
    end

    def raise_error
      raise @err if @err
    end

    def set_error(err)
      @err = err
    end
  end

  def create_all_types(fields)
    @n::AllTypes.new(fields).tap do |af|
      enum = fields.keys.first.to_s.sub(/^an?_/, '')
      af.field = enum.to_sym
    end
  end

  def setup
    setup_server
    set_handler Handler.new(@n)
  end

  def test_returning_struct
    send_to_server do
      assert @client.get_all_types.field.nil?
    end
  end

  def test_returning_a_list_of_structs
    l = [@n::Element.new(:id => 1, :name => "one"), @n::Element.new(:id => 2, :name => "two")]
    @handler.set_all_types create_all_types(:a_list_of_structs => l)

    at = send_to_server do
      @client.get_all_types
    end

    assert_equal :list_of_structs, at.field
    assert_equal 2, at.a_list_of_structs.size
    el = at.a_list_of_structs[0]
    assert_equal 1, el.id
    assert_equal "one", el.name
    el = at.a_list_of_structs[1]
    assert_equal 2, el.id
    assert_equal "two", el.name
  end

  def test_returning_a_map
    ascii = Hash[*(0...128).map{|n| [n, n.chr]}.flatten]
    @handler.set_all_types create_all_types(:a_map => ascii)

    at = send_to_server do
      @client.get_all_types
    end

    assert_equal :map, at.field
    assert_equal ascii, at.a_map
  end

  def test_returning_a_set
    require 'prime'
    primes = Prime::instance.each(256).to_a
    @handler.set_all_types create_all_types(:a_set => primes + primes)

    at = send_to_server do
      @client.get_all_types
    end

    assert_equal :set, at.field
    assert_equal Set.new(primes), at.a_set
  end

  def test_raise_no_error
    send_to_server do
      assert @client.raise_error.nil?
    end
  end

  def test_raise_first_error
    err = @n::AnException.new :message => "An error occurred", :backtrace => caller
    @handler.set_error err
    exception = send_to_server do
      assert_raises @n::AnException do
        @client.raise_error
      end
    end

    assert_equal err.message, exception.message
    assert_equal err.backtrace, exception.backtrace
  end

  def test_raise_second_error
    @handler.set_error @n::AnotherException.new
    send_to_server do
      assert_raises @n::AnotherException do
        @client.raise_error
      end
    end
  end
end
