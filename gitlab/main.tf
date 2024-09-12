provider "gitlab" {
  base_url = format("%s/api/v4/", var.gitlab_auth.url)
  token = var.gitlab_auth.token
}

resource "gitlab_application" "applications" {
  for_each = var.gitlab.applications
  scopes       = each.value.scopes
  name         = each.key
  redirect_url = templatefile("template/redirect_url.tftpl", { applications = each.value.redirect_url })
}

resource "gitlab_group" "namespaces" {
  for_each = { for k in var.gitlab.namespaces: k => {} }
  name        = each.key
  path        = each.key
  description = format("%s Namespace", each.key)

  push_rules {
    author_email_regex     = format ("%s$", var.gitlab.email_suffix)
    commit_committer_check = true
    member_check           = true
    prevent_secrets        = true
  }
}

resource "gitlab_user" "users" {
  for_each = { for k, v in var.users: k => v if v.gitlab != null  }
  name             = each.key
  username         = each.key
  email            = each.value.email
  is_admin         = each.value.gitlab.is_admin
  namespace_id     = gitlab_group.namespaces["${each.value.gitlab.namespace}"] == null ? "" : gitlab_group.namespaces["${each.value.gitlab.namespace}"].id
  reset_password   = true
  state            = each.value.gitlab.state
}
