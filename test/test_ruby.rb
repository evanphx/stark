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
    ruby.run ast
    ns = Module.new
    ns.module_eval stream.string
    assert ns::Foo
    assert ns::Bar
  end
end
