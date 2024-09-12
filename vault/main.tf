provider "vault" {
  address = var.vault_auth.url
  token = var.vault_auth.token
}
resource "vault_mount" "mount" {
  for_each = var.vault.repositories
  path        = each.key
  type        = each.value.type
  options = each.value.options
  description = each.value.description
}

resource "vault_policy" "policy" {
  for_each = var.vault.policies
  name = each.key
  policy = templatefile("template/policy.tftpl", { policies = each.value })
}

resource "vault_identity_entity" "entity" {
  for_each = { for k, v in var.users: k => v if v.vault != null  }
  name = each.key
  policies = each.value.policies
}

resource "vault_identity_entity_alias" "entity-alias" {
  for_each = { for k, v in var.users: k => v if v.vault != null  }
  name            = each.key
  mount_accessor  = vault_jwt_auth_backend.oidc[0].accessor
  canonical_id    = vault_identity_entity.entity[each.key].id
}

locals {
  oidc_path = "oidc"
  oidc_type = "oidc"
}

resource "vault_jwt_auth_backend" "oidc" {
  count  = var.vault.auth_method.oidc == null ? 0 : 1
  description         = "OIDC Auth Method"
  path                = local.oidc_path
  type                = local.oidc_type
  oidc_discovery_url  = var.vault.auth_method.oidc.oidc_discovery_url
  oidc_client_id      = var.vault.auth_method.oidc.oidc_client_id
  default_role        = var.vault.auth_method.oidc.default_role == null ? "" : var.vault.auth_method.oidc.default_role.name
  oidc_client_secret  = var.vault.auth_method.oidc.oidc_client_secret
  bound_issuer        = var.vault.auth_method.oidc.bound_issuer
  tune {
      listing_visibility = "unauth"
  }
}

resource "vault_jwt_auth_backend_role" "default" {
  count  =  var.vault.auth_method.oidc.default_role == null ? 0 : 1
  backend = local.oidc_type
  role_name = var.vault.auth_method.oidc.default_role.name
  user_claim = "nickname"
  allowed_redirect_uris = ["${var.vault.url}/ui/vault/auth/${local.oidc_path}/oidc/callback", "http://localhost:8250/oidc/callback"]
  bound_audiences = [var.vault.auth_method.oidc.oidc_client_id]
  oidc_scopes = ["openid"]
  role_type = "oidc"
  token_policies = var.vault.auth_method.oidc.default_role.policies
  token_ttl = 3600
  claim_mappings = {
    nickname = "nickname"
  }
}