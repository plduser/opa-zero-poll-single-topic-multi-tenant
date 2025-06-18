package policies.rbac

import data.policies.access
import data.policies.roles

default allow := false

allow if {
  user := input.user
  app := input.app
  tenant := input.tenant_id
  company := input.company_id
  action := input.action

  access.has_tenant_access(user, tenant)
  access.has_company_access(user, tenant, company)
  roles.has_permission(user, app, action)
}
