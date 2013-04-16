struct User {
  1:string first_name,
  2:string last_name,
  3:string email
}

struct FavoriteUsers {
  1:set<User>
}

service UserService {
  bool add_user(1:User user),
  set<User> get_users(),
  list<User> active_users()
}
