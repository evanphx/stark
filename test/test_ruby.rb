require 'test/unit'
require 'stark'
require 'stark/ruby'

class TestRuby < Test::Unit::TestCase
  def create_ns_module(name, lang = 'rb')
    ast = Stark::Parser.ast <<-EOM
namespace #{lang} #{name}
enum Status {
  DEAD
  ALIVE
}
  EOM

    stream = StringIO.new
    ruby = Stark::Ruby.new stream

    ruby.run ast

    ns = Module.new

    ns.module_eval stream.string
    ns
  end

  def test_namespace1
    ns = create_ns_module 'Blah'
    assert ns::Blah
    assert ns::Blah::Enum_Status
  end

  def test_namespace2
    ns = create_ns_module 'Blah.Blerg'
    assert ns::Blah::Blerg
    assert ns::Blah::Blerg::Enum_Status
  end

  def test_namespace3
    ns = create_ns_module 'Blah.Blerg', '*'
    assert ns::Blah::Blerg
    assert ns::Blah::Blerg::Enum_Status
  end

  def test_namespace4
    ns = create_ns_module 'Blah.Blerg', 'c'
    assert ns::Enum_Status
  end

  def test_forward_declaration
    ast = Stark::Parser.ast <<-EOM
struct Foo {
  1: Bar bar
}

struct Bar {
  1: i32 ids
}
  EOM

    stream = StringIO.new
    ruby = Stark::Ruby.new stream
    e = assert_raise RuntimeError do
      ruby.run ast
    end
    assert_equal 'Unknown type <Bar>', e.message
  end

  def test_function_result_of_struct_with_field_list_of_struct
    ast = Stark::Parser.ast <<-EOM
struct Foo {
  1: i32 id
}

struct Bar {
  1: list<Foo> foo_list
}

service Baz {
  Bar get(1: i32 id)
}
    EOM

    stream = StringIO.new
    ruby = Stark::Ruby.new stream
    assert_nothing_raised do
      ruby.run ast
    end
  end

  def test_function_result_of_struct_with_list_of_enum
    ast = Stark::Parser.ast <<-EOM
enum Foo {
  QUUX
}

struct Bar {
  1: list<Foo> foo_list
}

service Baz {
  Bar get(1: i32 id)
}
    EOM

    stream = StringIO.new
    ruby = Stark::Ruby.new stream
    assert_nothing_raised do
      ruby.run ast
    end
  end
end
