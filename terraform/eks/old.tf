# locals {
#   common_tags = {
#     Terraform   = "true"
#     Environment = var.environment
#     Region      = var.aws_region
#   }
# }

# module "eks" {
#   source  = "terraform-aws-modules/eks/aws"
#   version =  "~> 21.0"#~> 20.31

#   cluster_name    = "${var.cluster_name}-${var.environment}"
#   cluster_version = var.cluster_version

#   bootstrap_self_managed_addons            = true
#   cluster_endpoint_public_access           = true
#   enable_cluster_creator_admin_permissions = true

# #   # EKS Addons
# #   cluster_addons = {
# #     coredns                = {}
# #     eks-pod-identity-agent = {}
# #     kube-proxy             = {}
# #     vpc-cni                = {}
# #     aws-ebs-csi-driver     = {}
# #     aws-efs-csi-driver     = {}
# #   }

#   vpc_id     = var.vpc_id
#   subnet_ids = var.private_subnet_ids

#   cluster_security_group_additional_rules = {
#     node-pod = {
#       cidr_blocks = ["0.0.0.0/0"]
#       description = "Allow all traffic from remote node/pod network"
#       from_port   = 0
#       to_port     = 0
#       protocol    = "all"
#       type        = "ingress"
#     }
#   }


#   eks_managed_node_groups = {


#     default = {

#       description    = "EKS managed Default node group"
#       ami_type       = "AL2023_x86_64_STANDARD"
#       instance_types = ["t3.medium", "t3a.medium"]

#       labels = {
#         Name = "default"
#       }

#       min_size     = 2
#       max_size     = 4
#       desired_size = 2

#       create_iam_role = true

#       iam_role_additional_policies = {
#         Administrator                      = "arn:aws:iam::aws:policy/AdministratorAccess"
#         AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#         AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#         AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#         ElasticLoadBalancingFullAccess     = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
#         AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
#         combined                           = aws_iam_policy.eks_node.arn
#       }

#       launch_template = {
#         block_device_mappings = {
#           xvda = {
#             device_name = "/dev/xvda"
#             ebs = {
#               volume_size           = 100
#               volume_type           = "gp3"
#               iops                  = 3000
#               throughput            = 150
#               delete_on_termination = true
#             }
#           }
#         }
#       }

#       authentication_mode = "API"

#       tags = merge(var.tags, local.common_tags)

#     }
#   }
# }



# resource "aws_iam_policy" "eks_node" {
#   name        = "${var.cluster_name}-eks-node"
#   description = "Policy Node Group EKS"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [

#       #VPC (AmazonEKS_CNI_Policy)
#       {
#         Effect = "Allow"
#         Action = [
#           "ec2:Describe*",
#           "ec2:CreateNetworkInterface",
#           "ec2:DeleteNetworkInterface",
#           "ec2:AssignPrivateIpAddresses",
#           "ec2:UnassignPrivateIpAddresses",
#           "ec2:ModifyNetworkInterfaceAttribute"
#         ]
#         Resource = "*"
#       },

#       # ECR ReadOnly
#       {
#         Effect = "Allow"
#         Action = [
#           "ecr:GetAuthorizationToken",
#           "ecr:BatchCheckLayerAvailability",
#           "ecr:GetDownloadUrlForLayer",
#           "ecr:BatchGetImage"
#         ]
#         Resource = "*"
#       },
#       # AutoScaling
#       {
#         Effect = "Allow"
#         Action = [
#           "autoscaling:Describe*",
#           "autoscaling:DescribeTags",
#           "elasticloadbalancing:DescribeTags"
#         ]
#         Resource = "*"
#       },
#       # SSM
#       {
#         Effect = "Allow"
#         Action = [
#           "ssm:Describe*",
#           "ssm:Get*",
#           "ssm:List*"
#         ]
#         Resource = "*"
#       },
#       # ELB
#       {
#         Effect = "Allow"
#         Action = [
#           "elasticloadbalancing:*"
#         ]
#         Resource = "*"
#       },
#       # EC2
#       {
#         Effect = "Allow"
#         Action = [
#           "ec2:Describe*"
#         ]
#         Resource = "*"
#       },
#       # WAF ReadOnly
#       {
#         Effect = "Allow"
#         Action = [
#           "waf:List*",
#           "waf:Get*",
#           "waf:Describe*"
#         ]
#         Resource = "*"
#       },
#       # SecretsManager ReadWrite
#       {
#         Effect = "Allow"
#         Action = [
#           "secretsmanager:GetSecretValue",
#           "secretsmanager:PutSecretValue",
#           "secretsmanager:DescribeSecret",
#           "secretsmanager:ListSecrets"
#         ]
#         Resource = "*"
#       },
#       # S3 Full
#       {
#         Effect = "Allow"
#         Action = [
#           "s3:*"
#         ]
#         Resource = "*"
#       },
#       # CloudWatch Full
#       {
#         Effect = "Allow"
#         Action = [
#           "cloudwatch:*"
#         ]
#         Resource = "*"
#       }
#     ]
#   })

#   tags = merge(var.tags, local.common_tags)
# }

# resource "aws_iam_policy" "external_secrets" {
#   name        = "${var.cluster_name}-external-secrets"
#   description = "policy for external secrets operator access Secret Manager"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "BasePermissions"
#         Effect = "Allow"
#         Action = [
#           "secretsmanager:*",
#           "docdb-elastic:GetCluster",
#           "docdb-elastic:ListClusters",
#           "ec2:DescribeSecurityGroups",
#           "ec2:DescribeSubnets",
#           "ec2:DescribeVpcs",
#           "kms:DescribeKey",
#           "kms:ListAliases",
#           "kms:ListKeys",
#           "tag:GetResources"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "ReadSecrets"
#         Effect = "Allow"
#         Action = [
#           "secretsmanager:GetSecretValue",
#           "secretsmanager:DescribeSecret"
#         ]
#         Resource = "*"
#       }
#     ]
#   })

#   tags = merge(var.tags, local.common_tags)
# }

# resource "aws_iam_role" "external_secrets" {
#   name = "ExternalSecretsEKS"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Federated = module.eks.oidc_provider_arn
#         }
#         Action = "sts:AssumeRoleWithWebIdentity"
#         Condition = {
#           StringEquals = {
#             # Ajuste conforme o namespace e service account do External Secrets
#             "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:external-secrets:external-secrets"
#           }
#         }
#       }
#     ]
#   })

#   tags = merge(var.tags, local.common_tags)
# }

# resource "aws_iam_role_policy_attachment" "external_secrets_full_attach" {
#   role       = aws_iam_role.external_secrets.name
#   policy_arn = aws_iam_policy.external_secrets.arn
# }

# resource "helm_release" "argocd" {
#   name       = "argocd"
#   repository = "https://argoproj.github.io/argo-helm"
#   chart      = "argo-cd"
#   version    = "10.4.0"
#   namespace  = "argocd"

#   create_namespace = true

#   depends_on = [module.eks]
# }