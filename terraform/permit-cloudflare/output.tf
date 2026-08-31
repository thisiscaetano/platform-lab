output "cloudflare_sg_ids" {
  value = aws_security_group.this[*].id
}