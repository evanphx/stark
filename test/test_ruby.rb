require 'test/unit'
require 'stark'
require 'stark/ruby'

class TestRuby < Test::Unit::TestCase
  def test_namespace
    ast = Stark::Parser.ast <<-EOM
namespace rb Blah
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

    assert ns::Blah
    assert ns::Blah::Enum_Status
  end
end
