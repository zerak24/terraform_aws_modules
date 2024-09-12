provider "pritunl" {
  url      = var.pritunl_auth.url
  token    = var.pritunl_auth.token
  secret   = var.pritunl_auth.secret
  insecure = false
}

resource "pritunl_organization" "organization" {
  name = project.company
}

resource "pritunl_server" "test" {
  for_each = var.pritunl.servers
  name = each.key

  organization_ids = [
    pritunl_organization.organization.id
  ]

  dynamic "route" {
    for_each = each.value.routes
    content {
      network = route.value.network
      comment = route.key
      nat     = try(route.value.nat, true)
    }

  }
}

resource "pritunl_user" "test" {
  for_each = { for k, v in var.users: k => v if v.pritunl != null  }
  name            = each.key
  organization_id = pritunl_organization.organization.id
  email           = each.value.email
  groups = each.value.pritunl.groups
}
