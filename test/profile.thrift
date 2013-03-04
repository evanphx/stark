struct UserProfile {
  1: i32 uid,
  2: string name,
  3: string blurb
}

struct UserStatus {
  1: UserProfile profile,
  2: bool active
}

enum Status {
  ON
  OFF
  DEAD
  ALIVE
}

exception RockTooHard {
  1: i32 volume
}

service UserStorage {
  void store(1: UserProfile xuser),
  UserProfile retrieve(1: i32 xuid),
  void set_map(1: map<string, string> m),
  map<string, string> last_map(),
  void set_list(1: list<string> l),
  list<string> last_list(),
  void set_status(1: Status s),
  Status last_status(),
  i32 volume_up() throws (1: RockTooHard exc),
  oneway void make_bitcoins(),
  i32 add(1: i32 a, 2: i32 b),
  UserStatus user_status(),
  void set_user_status(1: UserStatus stat)
}

