locals {
  local_custom_error_response = [{
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
    }, {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }]
  tags = {
    Terraform   = "true"
    Company     = var.project.company
    Environment = var.project.env
  }
  name = format("%s-%s-%s", var.project.company, var.project.env, var.s3.name)
}

module "cloudfront" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-cloudfront.git?ref=v3.4.0"

  aliases                       = var.cloudfront.aliases
  comment                       = local.name
  is_ipv6_enabled               = true
  price_class                   = "PriceClass_All"
  wait_for_deployment           = false
  create_origin_access_identity = true
  default_root_object           = var.s3.default_root_object

  origin_access_identities = {
    s3_bucket_one = "My awesome CloudFront can access"
  }

  origin = {
    s3_one = {
      domain_name = module.s3.s3_bucket_bucket_regional_domain_name
      origin_id   = "s3_one"

      s3_origin_config = {
        origin_access_identity = "s3_bucket_one"
      }
    }
  }

  default_cache_behavior = var.cloudfront.default_cache_behavior

  ordered_cache_behavior = var.cloudfront.ordered_cache_behavior == null ? [] : var.cloudfront.ordered_cache_behavior

  viewer_certificate = {
    acm_certificate_arn      = lookup(var.cloudfront.viewer_certificate.acm_certificate, "")
    ssl_support_method       = lookup(var.cloudfront.viewer_certificate, "ssl_support_method", "sni-only")
    minimum_protocol_version = lookup(var.cloudfront.viewer_certificate, "minimum_protocol_version", "TLSv1.2_2018")
  }

  custom_error_response = var.cloudfront.custom_error_response == null ? local.local_custom_error_response : var.cloudfront.custom_error_response

  geo_restriction = var.cloudfront.geo_restriction == null ? {} : var.cloudfront.geo_restriction

  tags       = local.tags
  depends_on = [module.s3]
}

module "s3" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v4.1.2"

  bucket        = local.name
  acl           = var.s3.acl
  force_destroy = true

  tags = local.tags
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = ["${module.s3.s3_bucket_arn}/*", "${module.s3.s3_bucket_arn}"]

    principals {
      type        = "AWS"
      identifiers = module.cloudfront.cloudfront_origin_access_identity_iam_arns
    }
  }

  statement {
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = ["${module.s3.s3_bucket_arn}/*", "${module.s3.s3_bucket_arn}"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [module.cloudfront.cloudfront_distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = module.s3.s3_bucket_id
  policy = data.aws_iam_policy_document.s3_policy.json
}

