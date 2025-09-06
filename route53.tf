# Route53 DNS Configuration (Optional)

# Data source for existing hosted zone
data "aws_route53_zone" "main" {
  count = var.enable_route53 && var.domain_name != "" ? 1 : 0

  name         = var.domain_name
  private_zone = false
}

# A record pointing to the load balancer
resource "aws_route53_record" "main" {
  count = var.enable_route53 && var.domain_name != "" ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# CNAME record for www subdomain
resource "aws_route53_record" "www" {
  count = var.enable_route53 && var.domain_name != "" ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.domain_name]
}
