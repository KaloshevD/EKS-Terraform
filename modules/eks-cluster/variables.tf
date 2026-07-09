variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC created for this cluster."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across. Recommend at least 2 for HA, 3 for production."
  type        = list(string)
}

variable "private_subnet_newbits" {
  description = "Newbits passed to cidrsubnet() for private (node) subnets."
  type        = number
  default     = 4
}

variable "public_subnet_newbits" {
  description = "Newbits passed to cidrsubnet() for public (NAT/ALB) subnets."
  type        = number
  default     = 8
}

variable "enable_nat_gateway" {
  description = "Whether to provision NAT gateway(s) for private subnet egress."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ. Cheaper, less resilient - fine for dev/staging, avoid for production."
  type        = bool
  default     = false
}

variable "node_groups" {
  description = <<-EOT
    Map of EKS managed node group configurations. Key is the node group name.
    Example:
      {
        general = {
          instance_types = ["t3.medium"]
          capacity_type  = "ON_DEMAND"
          min_size       = 2
          max_size       = 6
          desired_size   = 2
          labels         = { role = "general" }
          taints         = []
        }
      }
  EOT
  type = map(object({
    instance_types = list(string)
    capacity_type  = optional(string, "ON_DEMAND")
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = optional(number, 50)
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = {
    general = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 6
      desired_size   = 2
    }
  }
}

variable "enable_fargate" {
  description = "Whether to create Fargate profiles in addition to (or instead of) managed node groups."
  type        = bool
  default     = false
}

variable "fargate_profiles" {
  description = <<-EOT
    Map of Fargate profile configurations, keyed by profile name. Only used
    when enable_fargate = true. Example:
      {
        default = {
          selectors = [{ namespace = "default" }]
        }
        kube_system = {
          selectors = [{ namespace = "kube-system" }]
        }
      }
  EOT
  type = map(object({
    selectors = list(object({
      namespace = string
      labels    = optional(map(string), {})
    }))
  }))
  default = {}
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS API server endpoint is publicly reachable. Set false + use cluster_endpoint_public_access_cidrs or VPN/Direct Connect for stricter customer environments."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public API endpoint, when public access is enabled."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_irsa" {
  description = "Create the OIDC provider needed for IAM Roles for Service Accounts (IRSA). Required for Project 3's operator to assume fine-grained IAM roles from within pods."
  type        = bool
  default     = true
}

variable "cluster_log_types" {
  description = "EKS control plane log types to enable and ship to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "tags" {
  description = "Tags applied to all created resources."
  type        = map(string)
  default     = {}
}
