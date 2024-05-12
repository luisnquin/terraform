
resource "aws_acm_certificate" "luisquinones_me" {
  domain_name       = "*.luisquinones.me"
  validation_method = "DNS"
  provider          = aws.virginia
}

resource "cloudflare_record" "aws_luisquinones_me" {
  for_each = {
    for dvo in aws_acm_certificate.luisquinones_me.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
  } }

  name    = each.value.name
  value   = each.value.record
  type    = each.value.type
  zone_id = var.cloudflare_zone_id

  depends_on = [
    aws_acm_certificate.luisquinones_me
  ]
}

resource "aws_acm_certificate_validation" "luisquinones_me" {
  certificate_arn = aws_acm_certificate.luisquinones_me.arn
  provider        = aws.virginia
  depends_on = [
    cloudflare_record.aws_luisquinones_me
  ]
}
