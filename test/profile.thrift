struct UserProfile {
  1: i32 uid,
  2: string name,
  3: string blurb
}

enum Status {
  ON
  OFF
  DEAD
  ALIVE
}

service UserStorage {
  void store(1: UserProfile xuser),
  UserProfile retrieve(1: i32 xuid),
  void set_map(1: map<string, string> m),
  map<string, string> last_map(),
  void set_list(1: list<string> l),
  list<string> last_list(),
  void set_status(1: Status s),
  Status last_status()
}

