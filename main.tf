
module "personal_s3" {
  source = "./modules/s3"
}

module "luis_quinones_me_acm" {
  source = "./modules/acm"

  domain_name = "luisquinones.me"

  providers = {
    aws = aws.virginia
  }
}

resource "aws_s3_object" "root" {
  bucket       = module.personal_s3.id
  key          = "public/cdn/index.txt"
  content_type = "text/plain"
  source       = "assets/index.txt"
  etag         = filemd5("assets/index.txt")
}

module "wishlist" {
  source = "terraform-aws-modules/cloudfront/aws"

  aliases = ["wishlist.luisquinones.me"]

  comment                       = "[tf] CloudFront distribution to put the wishlist :OOO"
  enabled                       = true
  is_ipv6_enabled               = true
  price_class                   = "PriceClass_100"
  retain_on_delete              = false
  wait_for_deployment           = false
  create_origin_access_identity = true
  origin_access_identities = {
    personal_bucket = "Origin access identity for my wishlist"
  }

  origin = {
    personal_bucket = {
      domain_name = module.personal_s3.bucket_domain_name
      s3_origin_config = {
        origin_access_identity = "personal_bucket"
      }
    }
  }

  geo_restriction = {
    restriction_type = "blacklist"
    locations        = ["RU", "CN", "IN", "SA", "FI"] # https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
  }

  default_cache_behavior = {
    target_origin_id       = "personal_bucket"
    viewer_protocol_policy = "allow-all"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = true
  }

  ordered_cache_behavior = [
    {
      path_pattern           = "/public/wishlist/*"
      target_origin_id       = "personal_bucket"
      viewer_protocol_policy = "redirect-to-https"

      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods  = ["GET", "HEAD"]
      compress        = true
      query_string    = false
    }
  ]

  custom_error_response = {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/"
    error_caching_min_ttl = 10
  }

  viewer_certificate = {
    acm_certificate_arn = module.luis_quinones_me_acm.acm_arn
    ssl_support_method  = "sni-only"
  }
}


module "cdn" {
  source = "terraform-aws-modules/cloudfront/aws"

  aliases = ["cdnx.luisquinones.me"]

  comment                       = "[tf] CloudFront distribution that acts as a personal CDN"
  enabled                       = true
  is_ipv6_enabled               = true
  price_class                   = "PriceClass_100"
  retain_on_delete              = false
  wait_for_deployment           = false
  create_origin_access_identity = true
  origin_access_identities = {
    personal_bucket = "Origin access identity for ${module.personal_s3.id}"
  }

  origin = {
    personal_bucket = {
      domain_name = module.personal_s3.bucket_domain_name
      s3_origin_config = {
        origin_access_identity = "personal_bucket"
      }
    }
  }

  geo_restriction = {
    restriction_type = "blacklist"
    locations        = ["RU", "CN", "IN", "SA", "FI"] # https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
  }

  default_cache_behavior = {
    target_origin_id       = "personal_bucket"
    viewer_protocol_policy = "allow-all"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = true
  }

  ordered_cache_behavior = [
    {
      path_pattern           = "/public/cdn/*"
      target_origin_id       = "personal_bucket"
      viewer_protocol_policy = "redirect-to-https"

      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods  = ["GET", "HEAD"]
      compress        = true
      query_string    = false
    }
  ]

  custom_error_response = {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/"
    error_caching_min_ttl = 10
  }

  viewer_certificate = {
    acm_certificate_arn = module.luis_quinones_me_acm.acm_arn
    ssl_support_method  = "sni-only"
  }
}

data "aws_iam_policy_document" "public" {
  statement {
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = concat(
        module.cdn.cloudfront_origin_access_identity_iam_arns,
        module.wishlist.cloudfront_origin_access_identity_iam_arns
      )
    }

    resources = [
      "${module.personal_s3.arn}/public/cdn/*"
    ]

    actions = [
      "s3:GetObject"
    ]
  }
}

resource "aws_s3_bucket_policy" "cdn" {
  bucket = module.personal_s3.id
  policy = data.aws_iam_policy_document.public.json
}


data "cloudflare_zone" "luisquinones_me" {
  name = "luisquinones.me"
}

resource "cloudflare_record" "cdn" {
  type    = "CNAME"
  name    = "cdnx"
  value   = module.cdn.cloudfront_distribution_domain_name
  proxied = false
  zone_id = data.cloudflare_zone.luisquinones_me.zone_id
  depends_on = [
    module.cdn
  ]
  comment = "[tf] CNAME record for cdn"
}
