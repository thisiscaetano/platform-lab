variable "iam_role_name" {
  description = "Nome da IAM Role para GitHub Actions e EKS"
  type        = string
  default     = "platform-lab-gitops"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "lab"
}
variable "ecr_repository" {
  type    = list(string)
  default = ["platform-lab-gitops-foundation", "hello-gitops"]
}
variable "github_org" {
  description = "GitHub organization ou usuário"
  type        = string
  sensitive   = true
}

variable "github_repositories" {
  description = "Lista de repositórios autorizados"
  type        = list(string)
  sensitive   = true
}
variable "aws_region" {
  default = "us-east-1"
}