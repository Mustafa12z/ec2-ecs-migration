output "fqdn" {
  description = "The record FQDN"
  value       = aws_route53_record.a.fqdn
}
