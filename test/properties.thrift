struct Property {
  1: i32 id
  2: string name
}

service Properties {
 list<Property> list(),
 Property get(1:i32 property_uid)
}
