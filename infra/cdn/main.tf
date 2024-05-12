
module "s3" {
  source = "../s3"

  cloudflare_api_token = var.cloudflare_api_token
}

module "acm" {
  source = "../acm"

  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_zone_id
}


resource "aws_s3_object" "root" {
  bucket       = module.s3.personal.id
  key          = "index.txt"
  content_type = "text/plain"
  source       = "assets/index.txt"
  etag         = filemd5("assets/index.txt")
}

resource "aws_cloudfront_origin_access_identity" "cdn" {
  comment = "[tf] Origin access identity for luisnquin's CDN (S3)"
}

data "aws_iam_policy_document" "cdn" {
  statement {
    sid    = "AllowCloudFrontDistribution"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        aws_cloudfront_origin_access_identity.cdn.iam_arn
      ]
    }

    resources = [
      "${module.s3.personal.arn}/resume.pdf"
    ]

    actions = [
      "s3:GetObject"
    ]
  }
}

resource "aws_s3_bucket_policy" "cdn" {
  bucket = module.s3.personal.id
  policy = data.aws_iam_policy_document.cdn.json
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "[tf] CloudFront distribution that acts as a personal CDN"
  default_root_object = aws_s3_object.root.key

  aliases = ["cdn.luisquinones.me"]

  origin {
    origin_id   = module.s3.personal.bucket_domain_name
    domain_name = module.s3.personal.bucket_domain_name
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.cdn.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = module.s3.personal.bucket_domain_name

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/"
    error_caching_min_ttl = 10
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "blacklist"
      locations        = ["RU", "CN", "IN", "SA", "FI"] # https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
    }
  }

  viewer_certificate {
    acm_certificate_arn            = module.acm.luisquinones_me_arn
    cloudfront_default_certificate = false
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  wait_for_deployment = true

  tags = {
    ManagedWith = "terraform"
    Goal        = "cdn"
  }

  depends_on = [
    aws_cloudfront_origin_access_identity.cdn
  ]
}

resource "cloudflare_record" "cdn" {
  type    = "CNAME"
  name    = "cdn"
  value   = aws_cloudfront_distribution.cdn.domain_name
  proxied = false
  zone_id = var.cloudflare_zone_id
  depends_on = [
    aws_cloudfront_distribution.cdn
  ]
}
