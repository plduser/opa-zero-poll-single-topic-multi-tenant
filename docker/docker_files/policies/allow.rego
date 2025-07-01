package policies.rbac

import data.policies.access
import data.policies.roles

default allow := false

allow if {
  user := input.user
  action := input.action
  resource := input.resource
  tenant := input.tenant_id

  access.has_tenant_access(user, tenant)
  roles.has_permission(user, action)
}
