struct UserProfile {
  1: i32 uid,
  2: string name,
  3: string blurb
}
service UserStorage {
  void store(1: UserProfile xuser),
  UserProfile retrieve(1: i32 xuid)
}

