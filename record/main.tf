locals {
  tags = {
    Terraform   = "true"
    Company     = var.project.company
    Environment = var.project.env
  }
}
module "zones" {
  count  = var.route53 == null ? 0 : 1
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-route53.git//modules/zones?ref=v4.1.0"

  zones = {
    for k, v in var.route53 : k => {}
  }

  tags = local.tags
}

module "records" {
  for_each = { for k, v in var.route53 : k => v.records if v.records != null }
  source   = "git::https://github.com/terraform-aws-modules/terraform-aws-route53.git//modules/records?ref=v4.1.0"

  zone_name = each.key

  records = each.value

  depends_on = [module.zones]
}

module "acm" {
  for_each = { for k, v in var.route53 : k => v.certificate if v.certificate != null }
  source   = "git::https://github.com/terraform-aws-modules/terraform-aws-acm.git?ref=v5.1.0"

  domain_name               = each.key
  zone_id                   = module.zones[0].route53_zone_zone_id["${each.key}"]
  validation_method         = "DNS"
  create_route53_records    = true
  subject_alternative_names = each.value.subject_alternative_names

  tags = local.tags
}