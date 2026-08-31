locals {
  sg_ids = aws_security_group.this[*].id

  cloudflare_rules = {
    for pair in setproduct(var.cloudflare_ips, range(length(local.sg_ids))) :
    "${pair[0]}-${pair[1]}" => {
      cidr  = pair[0]
      sg_id = local.sg_ids[pair[1]]
    }
  }
}
