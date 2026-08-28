variable "oidc_provider_url" {
  description = "URL do OIDC provider do EKS (sem o https://), ex: oidc.eks.us-east-1.amazonaws.com/id/XXXXX"
  type        = string
}

variable "namespace" {
  description = "Namespace do ESO"
  type        = string
  default     = "external-secrets"
}

variable "service_account_name" {
  description = "Nome da ServiceAccount do ESO"
  type        = string
  default     = "external-secrets-lab"
}

variable "role_name" {
  description = "Nome da IAM Role"
  type        = string
  default     = "SecretsManagerAccessRole-lab"
}
variable "aws_region" {
  default = "us-east-1"
}