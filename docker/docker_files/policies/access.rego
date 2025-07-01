package policies.access

# Check if user has access to specific tenant
has_tenant_access(user, tenant) if {
  some i
  data.acl[tenant].users[i].name == user
}
