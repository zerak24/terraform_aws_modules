variable "project" {
  type = object({
    env     = string
    company = string
  })
}

variable "route53" {
  type = map(object({
    certificate = optional(object({
      subject_alternative_names = optional(list(string))
    }))
    records = optional(list(any))
  }))
  default = null
}