data "aws_caller_identity" "current" {}

# Trust policy (assume role via OIDC/IRSA)
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.oidc_provider_url}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
  }
}

resource "aws_iam_role" "secrets_manager_access" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

# Permission policy
data "aws_iam_policy_document" "secrets_manager_access" {
  statement {
    sid    = "ListSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecrets",
      "secretsmanager:BatchGetSecretValue",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "GetSecretDetails"
    effect = "Allow"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "secrets_manager_access" {
  name   = "${var.role_name}-policy"
  policy = data.aws_iam_policy_document.secrets_manager_access.json
}

resource "aws_iam_role_policy_attachment" "secrets_manager_access" {
  role       = aws_iam_role.secrets_manager_access.name
  policy_arn = aws_iam_policy.secrets_manager_access.arn
}