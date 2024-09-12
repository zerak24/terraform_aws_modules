variable "project" {
  type = object({
    env        = string
    company = string
  })
}
variable "pritunl_auth" {
  type = object({
    url = string
    token = string
    secret = string
  })
}
variable "pritunl" {
  type = object({
    servers = optional(map(object({
      groups = optional(list(string))
      network = optional(string)
      port = optional(number)
      protocol = optional(string)
      routes = optional(map(object({
        network = optional(string)
      })))
    })))
  })
  default = []
}
variable "users" {
  type = map(object({
    email = optional(string)
    pritunl = optional(object({
      groups = optional(list(string))
    }))
  }))
  default = null
}