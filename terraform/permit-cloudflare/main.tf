resource "aws_security_group" "this" {
  count       = length(var.vpc_id)
  name        = "permit-cloudflare-lab"
  description = "acesso apenas para o Cloudflare"
  vpc_id      = var.vpc_id[count.index]
  tags = {
    Name        = "permit-cloudflare-lab"
    Environment = "lab"
  }
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each = local.cloudflare_rules

  security_group_id = each.value.sg_id
  description       = "Allow HTTPS from Cloudflare"
  cidr_ipv4         = each.value.cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = local.cloudflare_rules

  security_group_id = each.value.sg_id
  description       = "Allow HTTP from Cloudflare"
  cidr_ipv4         = each.value.cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "all_traffic" {
  count = length(var.vpc_id)

  security_group_id            = aws_security_group.this[count.index].id
  referenced_security_group_id = var.sg_target
  ip_protocol                  = "-1"
  description                  = "Allow all traffic to target security group"
}
