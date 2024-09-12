variable "project" {
  type = object({
    env        = string
    company = string
  })
}
variable "gitlab_auth" {
  type = object({
    url = string
    token = string
  })
}
variable "gitlab" {
  type = object({
    email_suffix = optional(string)
    applications = optional(map(object({
      scopes = optional(list(string))
      redirect_url = optional(list(string))
    })))
    namespaces = optional(list(string))
  })
  default = null
}
variable "users" {
  type = map(object({
    email = optional(string)
    gitlab = optional(object({
      is_admin = optional(bool, false)
      state = optiona(string, "active")
      namespace = optional(string)
    }))
  }))
  default = null
}