
variable "vpc_name" {
  description = "Name of the existing VPC"
  default     = "eks_vpc"
}

variable "cluster_name" {
  description = "EKS cluster name"
  default     = "node_web_app"
}

variable "cluster_role_arn" {
  description = "IAM Role ARN for the EKS cluster"
  type        = string
}
