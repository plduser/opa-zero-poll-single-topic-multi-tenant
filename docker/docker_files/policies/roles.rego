package policies.roles

# Check if user has permission to perform action based on their role
has_permission(user, action) if {
  # Get user's role from any tenant where user exists
  some tenant, i
  data.acl[tenant].users[i].name == user
  role := data.acl[tenant].users[i].role
  
  # Check if role has permission for this action
  role_permissions[role][_] == action
}

# Role definitions - what actions each role can perform
role_permissions := {
  "admin": ["read", "write", "delete"],
  "manager": ["read", "write"], 
  "user": ["read"],
  "viewer": ["read"]
}
