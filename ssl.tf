# SSL Certificate Configuration for dev environment
data aws_acm_certificate "dev_ssl_cert" {
#   count             = var.environment == "dev" ? 1 : 0
  domain = "demo.tejaswinichavan.me"
  statuses = ["ISSUED"]
  most_recent = true

#   tags = {
#     Name = "dev-SSL-Certificate"
#     Environment = "dev"
#   }
#   lifecycle {
#     create_before_destroy = true
#   }
}

# # DNS validation records for dev ACM certificate
# resource "aws_route53_record" "dev_cert_validation" {
#   count   = var.environment == "dev" ? length(aws_acm_certificate.dev_ssl_cert[0].domain_validation_options) : 0
#   zone_id = var.route53_zone_id
#   name    = element(aws_acm_certificate.dev_ssl_cert[0].domain_validation_options.*.resource_record_name, count.index)
#   type    = element(aws_acm_certificate.dev_ssl_cert[0].domain_validation_options.*.resource_record_type, count.index)
#   records = [element(aws_acm_certificate.dev_ssl_cert[0].domain_validation_options.*.resource_record_value, count.index)]
#   ttl     = 60
# }

# # Certificate validation for dev
# resource "aws_acm_certificate_validation" "dev_cert_validation" {
#   count                   = var.environment == "dev" ? 1 : 0
#   certificate_arn         = aws_acm_certificate.dev_ssl_cert[0].arn
#   validation_record_fqdns = aws_route53_record.dev_cert_validation.*.fqdn
# }

# # Placeholder for demo certificate (to be imported)
# resource "aws_acm_certificate" "demo_ssl_cert" {
#   count = var.environment == "demo" ? 1 : 0
  
#   # These are empty placeholders - actual values will come from the import
#   certificate_body = ""
#   private_key      = ""
  
#   lifecycle {
#     ignore_changes = all
#   }
# }

# # This should be a properly formatted locals block
# locals {
#   certificate_arn = var.environment == "dev" ? (
#     length(aws_acm_certificate.dev_ssl_cert) > 0 ? aws_acm_certificate.dev_ssl_cert[0].arn : ""
#   ) : var.imported_certificate_arn
# }