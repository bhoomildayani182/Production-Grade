# SSL/TLS Certificate Configuration with ACM and Let's Encrypt

# ACM Certificate (if using Route53)
resource "aws_acm_certificate" "main" {
  count = var.enable_ssl && var.domain_name != "" ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-certificate"
  }
}

# Route53 validation records
resource "aws_route53_record" "cert_validation" {
  count = var.enable_ssl && var.enable_route53 && var.domain_name != "" ? length(aws_acm_certificate.main[0].domain_validation_options) : 0

  allow_overwrite = true
  name            = tolist(aws_acm_certificate.main[0].domain_validation_options)[count.index].resource_record_name
  records         = [tolist(aws_acm_certificate.main[0].domain_validation_options)[count.index].resource_record_value]
  type            = tolist(aws_acm_certificate.main[0].domain_validation_options)[count.index].resource_record_type
  zone_id         = data.aws_route53_zone.main[0].zone_id
  ttl             = 60
}

# Certificate validation
resource "aws_acm_certificate_validation" "main" {
  count = var.enable_ssl && var.enable_route53 && var.domain_name != "" ? 1 : 0

  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = aws_route53_record.cert_validation[*].fqdn

  timeouts {
    create = "5m"
  }
}
