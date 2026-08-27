variable "cluster_name" {
  default = "platform-lab"
}

variable "cluster_version" {
  default = "1.36"
}
variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "prd"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  default = ""
}
variable "private_subnet_ids" {
  type    = list(string)
  default = ["", ""]
}
