enum WhichField {
  BOOL,
  BYTE,
  DOUBLE,
  I16,
  I32,
  I64,
  STRING,
  MAP,
  LIST,
  SET
}

struct AllTypes {
  1: bool a_bool
  2: byte a_byte
  3: double a_double
  4: i16 an_i16
  5: i32 an_i32
  6: i64 an_i64
  7: string a_string
  8: map<byte,string> a_map
  9: list<string> a_list
 10: set<i32> a_set
 11: WhichField field
 12: list<Element> a_list_of_structs
}

struct Element {
 1: i64 id
 2: string name
}

exception AnException {
  1: string message
  2: list<string> backtrace
}

exception AnotherException {
  1: string message
  2: list<string> backtrace
}

service Types {
  AllTypes get_all_types()
  void set_all_types(1:AllTypes at)
  void raise_error() throws(1:AnException ae, 2:AnotherException aae)
}
