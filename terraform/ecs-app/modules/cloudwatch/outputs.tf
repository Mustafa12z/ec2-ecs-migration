output "log_group_names" {
  description = "Map of log group name => created name"
  value       = { for k, v in aws_cloudwatch_log_group.this : k => v.name }
}
