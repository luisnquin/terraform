
data "cloudflare_zone" "this" {
  name = var.domain_name
}

resource "aws_acm_certificate" "this" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  subject_alternative_names = [
    "*.${var.domain_name}"
  ]
}

resource "cloudflare_record" "this" {
  type    = tolist(aws_acm_certificate.this.domain_validation_options)[0].resource_record_type
  name    = tolist(aws_acm_certificate.this.domain_validation_options)[0].resource_record_name
  value   = tolist(aws_acm_certificate.this.domain_validation_options)[0].resource_record_value
  zone_id = data.cloudflare_zone.this.zone_id

  depends_on = [
    aws_acm_certificate.this
  ]
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn = aws_acm_certificate.this.arn
  depends_on = [
    cloudflare_record.this
  ]
}
