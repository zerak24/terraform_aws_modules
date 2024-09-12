variable "project" {
  type = object({
    env        = string
    company = string
  })
}
variable "vault_auth" {
  type = object({
    url = string
    token = string
  })
}
variable "vault" {
  type = object({
    auth_method = optional(object({
      oidc = optional(object({
        oidc_discovery_url = optional(string)
        oidc_client_id = optional(string)
        default_role = optional(object({
          name = optional(string)
          policies = optional(list(string))
        }))
        oidc_client_secret = optional(string)
        bound_issuer = optional(string)
      }), {})
    }), {})
    repositories = optional(map(object({
      type = optional(string, "kv-v2")
      description = optional(string)
      options = optional(map(string))
    })), {})
    policies = optional(map(list(object({
      path = optional(string)
      capabilities = optional(list(string))
    }))), {})
  })
  default = null
}
variable "users" {
  type = map(object({
    vault = optional(object({
      policies = optional(list(string))
    }))
  }))
  default = null
}