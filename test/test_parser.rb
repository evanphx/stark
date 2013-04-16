require 'test/unit'
require 'stark/parser'

class TestParser < Test::Unit::TestCase
  def parse(data)
    tg = Stark::Parser.new data

    unless tg.parse
      tg.raise_error
    end

    assert tg.result

    return tg.result
  end

  def test_ccomment
    parse "/* blah */\n"
    parse "/* blah */ /* foo */\n"
  end

  def test_hcomment
    parse "# blah\n"
  end

  def test_const_value_in_struct
    parse <<-EOM
struct Hello {
  1: string greeting = "hello world"
}
    EOM
  end

  def test_enum
    parse <<-EOM
enum SomeEnum {
  ONE
  TWO
}
    EOM
  end

  def test_list
    parse <<-EOM
struct Foo {
  1: list<i32> ints
}
    EOM
  end

  def test_list_with_value
    parse <<-EOM
struct Foo {
  1: list<i32> ints = [1, 2, 2, 3],
}
    EOM
  end

  def test_list_with_struct
    parse <<-EOM
struct Foo {
  1: i32 uid
}
struct Bar {
  1: list<Foo> foos
}
    EOM
  end

  include Stark::Parser::AST

  def comment(text)
    Comment.new(text)
  end
  def field(index, type, name)
    Field.new(index, type, name)
  end
  def function(name, return_type, arguments)
    Function.new(name, return_type, arguments)
  end
  def include(path)
    Include.new(path)
  end
  def namespace(lang, namespace)
    Namespace.new(lang, namespace)
  end
  def service(name, functions)
    Service.new(name, functions)
  end
  def struct(name, fields)
    Struct.new(name, fields)
  end

  def list(t)
    List.new(t)
  end

  def map(a,b)
    Map.new(a,b)
  end

  def set(a)
    Set.new(a)
  end

  def assert_type(exc, acc)
    case exc
    when List, Set
      assert_type exc.value, acc.value
    when Map
      assert_type exc.key, acc.key
      assert_type exc.value, acc.value
    else
      assert_equal exc, acc
    end
  end

  def assert_field(f, idx, type, name)
    assert_equal idx, f.index
    assert_equal name, f.name
    assert_type type, f.type
  end

  def assert_func(f, ret_type, name, args)
    assert_type ret_type, f.return_type
    assert_equal name, f.name

    return if !args and !f.arguments

    args.zip(f.arguments).each do |exc, arg|
      assert_equal exc[0], arg.index
      assert_type exc[1], arg.type
      assert_equal exc[2], arg.name
    end
  end

  def test_throws
    o = parse <<-EOM
service Foo {
  i32 foo() throws (1: i32 code)
}
    EOM

    o = o.first

    assert_equal "Foo", o.name

    assert_func o.functions[0], "i32", "foo", nil
    assert_field o.functions[0].throws.first, 1, "i32", "code"
  end

  def test_include
    o = parse <<-EOM
include "test/blah.thrift"

    EOM

    assert_equal "test/blah.thrift", o.first.path
  end

  def test_include_expanded
    o = parse <<-EOM
include "test/blah.thrift"

    EOM

    o = Stark::Parser.expand o

    assert_equal "Blah", o.first.name
    assert_equal ["FOO", "BAR", "BAZ"], o.first.values
  end

  def test_include_to_include
    o = parse <<-EOM
include "test/include_blah.thrift"

    EOM

    o = Stark::Parser.expand o

    assert_equal "Blah", o.first.name
    assert_equal ["FOO", "BAR", "BAZ"], o.first.values
  end

  def test_ast
    parser = Stark::Parser.new <<-EOM
include "test/include_blah.thrift"
EOM

    o = parser.ast

    assert_equal "Blah", o.first.name
    assert_equal ["FOO", "BAR", "BAZ"], o.first.values
  end

  def test_s_ast
    o = Stark::Parser.ast <<-EOM
include "test/include_blah.thrift"
EOM

    assert_equal "Blah", o.first.name
    assert_equal ["FOO", "BAR", "BAZ"], o.first.values
  end

  def test_namespace
    o = parse <<-EOM
namespace rb Blah
    EOM

    ns = o.first

    assert_equal "rb", ns.lang
    assert_equal "Blah", ns.namespace
  end

  def test_spec
    data = File.read "test/ThriftSpec.thrift"

    tg = Stark::Parser.new data

    unless tg.parse
      tg.raise_error
    end

    ary = tg.result

    comments = ary.shift(19)
    comments.each { |c| assert_kind_of Comment, c }

    ns = ary.shift

    assert_equal "rb", ns.lang
    assert_equal "SpecNamespace", ns.namespace

    ns = ary.shift

    assert_equal "Hello", ns.name
    assert_equal 1, ns.fields.size
    f = ns.fields[0]

    assert_equal 1, f.index
    assert_equal "string", f.type
    assert_equal "greeting", f.name

    assert_equal "hello world", f.value.value

    e = ary.shift

    assert_equal ["ONE", "TWO"], e.values

    s = ary.shift

    assert_equal "StructWithSomeEnum", s.name
    assert_equal 1, s.fields.size
    f = s.fields.first

    assert_equal 1, f.index
    assert_equal "SomeEnum", f.type
    assert_equal "some_enum", f.name

    s = ary.shift
    assert_equal :union, s.type
    assert_equal "TestUnion", s.name
    assert_equal 5, s.fields.size

    fs = s.fields

    assert_field fs[0], 1, "string", "string_field"
    assert_field fs[1], 2, "i32", "i32_field"
    assert_field fs[2], 3, "i32", "other_i32_field"
    assert_field fs[3], 4, "SomeEnum", "enum_field"
    assert_field fs[4], 5, "binary", "binary_field"

    s = ary.shift
    assert_equal "Foo", s.name
    assert_equal 8, s.fields.size

    f = s.fields

    assert_field f[0], 1, "i32", "simple"
    assert_field f[1], 2, "string", "words"
    assert_equal "words", f[1].value.value

    assert_field f[2], 3, "Hello", "hello"
    assert_equal "greeting", f[2].value.values[0][0].value
    assert_equal "hello, world!", f[2].value.values[0][1].value

    assert_field f[3], 4, list("i32"), "ints"
    ints = f[3].value.values.map { |i| i.value }
    assert_equal [1, 2, 2, 3], ints

    assert_field f[4], 5, map("i32", map("string", "double")), "complex"

    assert_field f[5], 6, set("i16"), "shorts"
    ints = f[5].value.values.map { |i| i.value }
    assert_equal [5, 17, 239], ints

    assert_field f[6], 7, "string", "opt_string"
    assert_field f[7], 8, "bool", "my_bool"

    assert_equal ["optional"], f[6].options

    s = ary.shift

    assert_equal "Foo2", s.name
    assert_equal 1, s.fields.size

    assert_field s.fields[0], 1, "binary", "my_binary"

    s = ary.shift
    assert_equal "BoolStruct", s.name
    assert_equal 1, s.fields.size

    assert_field s.fields[0], 1, "bool", "yesno"
    assert_equal 1, s.fields[0].value.value

    s = ary.shift
    fs = s.fields

    assert_field fs[0], 1, list("bool"), "bools"
    assert_field fs[1], 2, list("byte"), "bytes"
    assert_field fs[2], 3, list("i16"), "i16s"
    assert_field fs[3], 4, list("i32"), "i32s"
    assert_field fs[4], 5, list("i64"), "i64s"
    assert_field fs[5], 6, list("double"), "doubles"
    assert_field fs[6], 7, list("string"), "strings"
    assert_field fs[7], 8, list(map("i16", "i16")), "maps"
    assert_field fs[8], 9, list(list("i16")), "lists"
    assert_field fs[9], 10, list(set("i16")), "sets"
    assert_field fs[10], 11, list("Hello"), "hellos"

    s = ary.shift
    assert_equal "Xception", s.name
    assert_field s.fields[0], 1, "string", "message"
    assert_field s.fields[1], 2, "i32", "code"
    assert_equal 1, s.fields[1].value.value

    s = ary.shift
    assert_equal "NonblockingService", s.name
    fs = s.functions

    assert_func fs[0], "Hello", "greeting", [[1, "bool", "english"]]
    assert_func fs[1], "bool", "block", nil
    assert_func fs[2], "void", "unblock", [[1, "i32", "n"]]
    assert_func fs[3], "void", "shutdown", nil
    assert_func fs[4], "void", "sleep", [[1, "double", "seconds"]]

    s = ary.shift
    assert_equal "My_union", s.name
    fs = s.fields
    assert_field fs[0], 1, "bool", "im_true"
    assert_field fs[1], 2, "byte", "a_bite"
    assert_field fs[2], 3, "i16", "integer16"
    assert_field fs[3], 4, "i32", "integer32"
    assert_field fs[4], 5, "i64", "integer64"
    assert_field fs[5], 6, "double", "double_precision"
    assert_field fs[6], 7, "string", "some_characters"
    assert_field fs[7], 8, "i32", "other_i32"
    assert_field fs[8], 9, "SomeEnum", "some_enum"
    assert_field fs[9], 10, map("SomeEnum", list("SomeEnum")), "my_map"

    s = ary.shift
    assert_equal "Struct_with_union", s.name
    fs = s.fields

    assert_field fs[0], 1, "My_union", "fun_union"
    assert_field fs[1], 2, "i32", "integer32"
    assert_field fs[2], 3, "string", "some_characters"

    s = ary.shift
    assert_equal "StructWithEnumMap", s.name

    s = ary.shift
    # comment

    s = ary.shift
    assert_equal "NestedListInList", s.name

    s = ary.shift
    assert_equal "NestedListInSet", s.name

    s = ary.shift
    assert_equal "NestedListInMapKey", s.name

    s = ary.shift
    assert_equal "NestedListInMapValue", s.name

    s = ary.shift # comment
    s = ary.shift
    assert_equal "NestedSetInList", s.name

    s = ary.shift
    assert_equal "NestedSetInSet", s.name

    s = ary.shift
    assert_equal "NestedSetInMapKey", s.name

    s = ary.shift
    assert_equal "NestedSetInMapValue", s.name

    s = ary.shift # comment
    s = ary.shift
    assert_equal "NestedMapInList", s.name

    s = ary.shift
    assert_equal "NestedMapInSet", s.name

    s = ary.shift
    assert_equal "NestedMapInMapKey", s.name

    s = ary.shift
    assert_equal "NestedMapInMapValue", s.name

    s = ary.shift
    assert_equal "HelloService", s.name
    fs = s.functions

    assert_func fs[0], list("Hello"), "all", nil
  end
end
