
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
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
  } }

  name    = each.value.name
  value   = each.value.record
  type    = each.value.type
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
