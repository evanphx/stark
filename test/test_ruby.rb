require 'test/unit'
require 'stark'
require 'stark/ruby'

class TestRuby < Test::Unit::TestCase
  def create_ruby(thrift, options = {})
    ast = Stark::Parser.ast thrift
    stream = StringIO.new
    ruby = Stark::Ruby.new stream
    options[:skip_prologue] = options[:skip_epilogue] = true if options[:only_ast]
    stream.string = '' if options[:skip_prologue]
    if options[:skip_epilogue]
      ast.each { |a| a.accept ruby }
    else
      ruby.run ast
    end
    stream.string
  end

  def create_ns_module(name, lang = 'rb')
    thrift = <<-EOM
namespace #{lang} #{name}
enum Status {
  DEAD
  ALIVE
}
  EOM

    ns = Module.new

    ns.module_eval create_ruby(thrift)
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
    code = <<-EOM
struct Foo {
  1: Bar bar
}

struct Bar {
  1: i32 ids
}
  EOM

    ns = Module.new
    ns.module_eval create_ruby code
    assert ns::Foo
    assert ns::Bar
  end

  def test_struct_attr_accessor
    ruby = create_ruby <<-EOM, :only_ast => true
struct Foo {
1:string str
2:map<string,string> map
3:i32 int
}
EOM
    assert ruby =~ %r{class\sFoo\s<\sStark::Struct
                       .*
                      attr_accessor\s:str
                       .*
                      attr_accessor\s:map
                       .*
                      attr_accessor\s:int}mx, "did not match:\n#{ruby}"
    ns = Module.new
    ns.module_eval ruby
    fields = ns::Foo.fields
    assert_equal({ 1 => :str, 2 => :map, 3 => :int }, fields)
  end

  def test_struct_set_field_number
    ruby = create_ruby <<-EOM, :only_ast => true
struct Foo {
3:string str
2:map<string,string> map
1:i32 int
}
EOM

    assert ruby =~ %r{class\sFoo\s<\sStark::Struct
                       .*
                      field_number\s3
                       .*
                      attr_accessor\s:str
                       .*
                      field_number\s2
                       .*
                      attr_accessor\s:map
                       .*
                      field_number\s1
                       .*
                      attr_accessor\s:int}mx, "did not match:\n#{ruby}"
    ns = Module.new
    ns.module_eval ruby
    fields = ns::Foo.fields
    assert_equal({ 3 => :str, 2 => :map, 1 => :int }, fields)
  end

  def test_to_struct_to_hash
    ruby = create_ruby <<-EOM, :only_ast => true
struct Foo {
1:string str
2:map<string,string> map
3:i32 int
}
EOM

    ns = Module.new
    ns.module_eval ruby
    assert ns::Foo

    foo = ns::Foo.new :str => "hi", :int => 20
    assert_equal({:str => "hi", :int => 20}, foo.to_hash)
  end

  def test_to_struct_to_hash_nested
    ruby = create_ruby <<-EOM, :only_ast => true
struct Bar {
1: string blah
}
struct Quux {
1: i32 int
}
struct Foo {
1:string str
2:list<Bar> bars
3:i32 int
4:Quux q
}
EOM

    ns = Module.new
    ns.module_eval ruby
    assert ns::Foo

    foo = ns::Foo.new :str => "hi", :int => 20
    foo.bars = [ns::Bar.new(:blah => "baz")]
    foo.q = ns::Quux.new(:int => 42)
    assert_equal({:str => "hi", :int => 20, :bars => [{:blah => "baz"}], :q => {:int => 42}}, foo.to_hash)
  end

  def test_to_hash_of_array_of_non_struct
    ruby = create_ruby <<-EOM, :only_ast => true
struct Foo {
  1:list<i32> ints
}
EOM

    ns = Module.new
    ns.module_eval ruby
    assert ns::Foo

    foo = ns::Foo.new :ints => [1, 2]
    assert_equal({:ints => [1, 2]}, foo.to_hash)
  end

  def test_to_struct_aref
    ruby = create_ruby <<-EOM, :only_ast => true
struct Foo {
1:string str
2:map<string,string> map
3:i32 int
}
EOM

    ns = Module.new
    ns.module_eval ruby
    assert ns::Foo

    foo = ns::Foo.new :str => "hi", :int => 20
    assert_equal "hi", foo["str"]
    assert_equal "hi", foo[:str]
    assert_equal "hi", foo[1]
    assert_equal 20,   foo["int"]
    assert_equal 20,   foo[:int]
    assert_equal 20,   foo[3]
    assert_equal ["hi", nil, 20], foo[1..3]
    assert_equal ["hi", 20], foo[1, 3]
    assert_equal ["hi", 20], foo[:str, :int]
  end

end
