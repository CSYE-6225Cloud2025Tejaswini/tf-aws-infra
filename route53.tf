# Route53 Record for Load Balancer
resource "aws_route53_record" "webapp" {
  zone_id = var.route53_zone_id
  name    = ""
  type    = "A"

  alias {
    name                   = aws_lb.webapp_lb.dns_name
    zone_id                = aws_lb.webapp_lb.zone_id
    evaluate_target_health = true
  }
}