require 'test/unit'

require 'stark'

require 'rubygems'
require 'thrift'

class TestStark < Test::Unit::TestCase
  def setup
    @m = Module.new
  end

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
    Stark.materialize file_path, @m
    assert @m.const_defined?(:Property)
  end

  def test_materialize_service_with_struct_set
    file_path = File.join(File.dirname(__FILE__), 'users.thrift')
    Stark.materialize file_path, @m
    assert @m.const_defined?(:User)
    assert @m.const_defined?(:FavoriteUsers)
  end

  def test_materialize_service_with_comments_and_no_ending_newline
    file_path = File.join(File.dirname(__FILE__), 'comments.thrift')
    Stark.materialize file_path, @m
    assert @m.const_defined?(:Foo)
  end

  def test_materialize_service_with_throws
    file_path = File.join(File.dirname(__FILE__), 'types.thrift')
    Stark.materialize file_path, @m
    assert @m.const_defined?(:Types)
  end

  def test_materialize_with_stringio
    file_path = File.join(File.dirname(__FILE__), 'types.thrift')
    io = StringIO.new(File.read(file_path))
    Stark.materialize io, @m
    assert @m.const_defined?(:Types)
  end

  def test_include_in_same_dir_not_working_dir
    Dir.chdir(File.dirname(__FILE__) + '/../') do
      file_path = File.join(File.dirname(__FILE__), 'include_blah.thrift')
      Stark.materialize file_path, @m
    end
  end
end
