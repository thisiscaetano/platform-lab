module "karpenter" {
  source = "thisiscaetano/karpenter_iam/aws"

  version = "1.0.3"

  cluster_name = var.cluster_name
  aws_region   = var.aws_region
}
#serviceAccount
resource "aws_eks_pod_identity_association" "karpenter" {
  cluster_name    = var.cluster_name
  namespace       = "karpenter"
  service_account = "karpenter"
  role_arn = module.karpenter.role_arn
}