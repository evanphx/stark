require 'test/unit'

require 'stark'

require 'rubygems'
require 'thrift'

class TestSpark < Test::Unit::TestCase
  module TestSparkScope;end

  def test_materialize_parsing_errors
    file_path = File.join(File.dirname(__FILE__), 'parsing_error.thrift')
    begin
     Stark.materialize file_path
    rescue => e
      error = e
    end
    assert(error, "A parsing exception should have been raised")
    assert_equal(Stark::Parser::ParseError, error.class)
    assert e.message.include?(file_path)
  end

  def test_materialize_service_with_struct_list
    file_path = File.join(File.dirname(__FILE__), 'properties.thrift')
    assert_nothing_raised do
      Stark.materialize file_path, TestSparkScope
    end
    assert TestSparkScope.const_defined?(:Property)
  end

  def test_materialize_service_with_struct_set
    file_path = File.join(File.dirname(__FILE__), 'users.thrift')
    assert_nothing_raised do
      Stark.materialize file_path, TestSparkScope
    end
    assert TestSparkScope.const_defined?(:User)
    assert TestSparkScope.const_defined?(:FavoriteUsers)
  end

  def test_materialize_service_with_comments
    file_path = File.join(File.dirname(__FILE__), 'comments.thrift')
    assert_nothing_raised do
      Stark.materialize file_path, TestSparkScope
    end
    assert TestSparkScope.const_defined?(:Foo)
  end

  def test_materialize_service_with_throws
    file_path = File.join(File.dirname(__FILE__), 'types.thrift')
    assert_nothing_raised do
      Stark.materialize file_path, TestSparkScope
    end
    assert TestSparkScope.const_defined?(:Types)
  end

  def test_materialize_with_stringio
    file_path = File.join(File.dirname(__FILE__), 'types.thrift')
    io = StringIO.new(File.read(file_path))
    m = Module.new
    assert_nothing_raised do
      Stark.materialize io, m
    end
    assert m.const_defined?(:Types)
  end

end
