package policies.access


has_tenant_access(user, tenant) if {
  tenant in data.access.tenants[user]
}

has_company_access(user, tenant, company) if {
  company in data.access.companies[user][tenant]
}
