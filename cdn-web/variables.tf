variable "project" {
  type = object({
    env     = string
    company = string
  })
}

variable "cloudfront" {
  type = object({
    aliases                  = optional(list(string))
    origin_access_identities = optional(map(string))
    default_cache_behavior   = optional(any)
    ordered_cache_behavior   = optional(list(any))
    viewer_certificate       = optional(map(string))
    geo_restriction          = optional(any)
    custom_error_response    = optional(any)
  })
}

variable "s3" {
  type = object({
    name                = string
    versioning          = optional(bool)
    acl                 = optional(string)
    default_root_object = optional(string, "index.html")
  })
}