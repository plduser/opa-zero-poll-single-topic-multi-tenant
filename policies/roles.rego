package policies.roles


has_permission(user, app, action) if {
  some role in data.roles.assignments[user][app]
  action in data.roles.definitions[role]
}
