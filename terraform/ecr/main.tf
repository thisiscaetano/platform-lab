resource "aws_ecr_repository" "hello-gitops" {
  count = length(var.ecr_repository)
  name  = var.ecr_repository[count.index]
  tags = {
    Environment = var.environment
  }
}
#OIDC gh provider
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.github.certificates[0].sha1_fingerprint
  ]

  tags = {
    Environment = var.environment
  }
}
#GitHub Actions via OIDC + EKS Pod Identity
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "gitops_assume_role" {

  # GitHub Actions
  statement {
    sid    = "GitHubActions"
    effect = "Allow"

    principals {
      type = "Federated"
      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        for repo in var.github_repositories :
        "repo:${var.github_org}*/${repo}*:*"
      ]
    }
  }

  # EKS Pod Identity
  statement {
    sid    = "EKSPodIdentity"
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "pods.eks.amazonaws.com"
      ]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "gitops" {
  name = var.iam_role_name

  assume_role_policy = data.aws_iam_policy_document.gitops_assume_role.json

  tags = {
    Environment = var.environment
  }
}

#ROLEECR
data "aws_iam_policy_document" "gitops_ecr" {

  statement {
    sid    = "ECRReadWrite"
    effect = "Allow"

    resources = ["*"]

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"

      values = [
        var.environment
      ]
    }
  }

  statement {
    sid    = "ECRAuthorization"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role_policy" "gitops_ecr" {
  name   = "${var.iam_role_name}-ecr"
  role   = aws_iam_role.gitops.id
  policy = data.aws_iam_policy_document.gitops_ecr.json
}