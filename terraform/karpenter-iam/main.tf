module "karpenter" {
  source = "thisiscaetano/karpenter_iam/aws"

  version = "1.0.2"

  account_id   = var.account_id
  oidc_id      = var.oidc_id
  cluster_name = var.cluster_name
  aws_region   = var.aws_region
}
