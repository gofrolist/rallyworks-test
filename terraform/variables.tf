variable "region" {
  type        = string
  description = "AWS Region"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.29"
  description = "Desired Kubernetes master version. If you do not specify a value, the latest available version is used"
}

variable "enabled_cluster_log_types" {
  type        = list(string)
  default     = []
  description = "A list of the desired control plane logging to enable. For more information, see https://docs.aws.amazon.com/en_us/eks/latest/userguide/control-plane-logs.html. Possible values [`api`, `audit`, `authenticator`, `controllerManager`, `scheduler`]"
}

variable "cluster_log_retention_period" {
  type        = number
  default     = 0
  description = "Number of days to retain cluster logs. Requires `enabled_cluster_log_types` to be set. See https://docs.aws.amazon.com/en_us/eks/latest/userguide/control-plane-logs.html."
}

variable "oidc_provider_enabled" {
  type        = bool
  default     = true
  description = "Create an IAM OIDC identity provider for the cluster, then you can create IAM roles to associate with a service account in the cluster, instead of using `kiam` or `kube2iam`. For more information, see https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html"
}

variable "instance_types" {
  type        = list(string)
  description = "Set of instance types associated with the EKS Node Group. Defaults to [\"t3.medium\"]. Terraform will only perform drift detection if a configuration value is provided"
}

variable "kubernetes_labels" {
  type        = map(string)
  description = "Key-value mapping of Kubernetes labels. Only labels that are applied with the EKS API are managed by this argument. Other Kubernetes labels applied to the EKS Node Group will not be managed"
  default     = {}
}

variable "desired_size" {
  type        = number
  description = "Desired number of worker nodes"
}

variable "max_size" {
  type        = number
  description = "The maximum size of the AutoScaling Group"
}

variable "min_size" {
  type        = number
  description = "The minimum size of the AutoScaling Group"
}

variable "cluster_encryption_config_enabled" {
  type        = bool
  default     = true
  description = "Set to `true` to enable Cluster Encryption Configuration"
}

variable "cluster_encryption_config_kms_key_id" {
  type        = string
  default     = ""
  description = "KMS Key ID to use for cluster encryption config"
}

variable "cluster_encryption_config_kms_key_enable_key_rotation" {
  type        = bool
  default     = true
  description = "Cluster Encryption Config KMS Key Resource argument - enable kms key rotation"
}

variable "cluster_encryption_config_kms_key_deletion_window_in_days" {
  type        = number
  default     = 10
  description = "Cluster Encryption Config KMS Key Resource argument - key deletion windows in days post destruction"
}

variable "cluster_encryption_config_kms_key_policy" {
  type        = string
  default     = null
  description = "Cluster Encryption Config KMS Key Resource argument - key policy"
}

variable "cluster_encryption_config_resources" {
  type        = list(any)
  default     = ["secrets"]
  description = "Cluster Encryption Config Resources to encrypt, e.g. ['secrets']"
}

variable "addons" {
  type = list(object({
    addon_name    = string
    addon_version = string
    # resolve_conflicts is deprecated, but we keep it for backwards compatibility
    # and because if not declared, Terraform will silently ignore it.
    resolve_conflicts           = optional(string, null)
    resolve_conflicts_on_create = optional(string, null)
    resolve_conflicts_on_update = optional(string, null)
    service_account_role_arn    = string
  }))
  default     = []
  description = "Manages [`aws_eks_addon`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) resources."
}

variable "private_ipv6_enabled" {
  type        = bool
  default     = false
  description = "Whether to use IPv6 addresses for the pods in the node group"
}

variable "subnets_per_az_count" {
  type        = number
  description = <<-EOT
    The number of subnet of each type (public or private) to provision per Availability Zone.
    EOT
  default     = 1

  validation {
    condition = var.subnets_per_az_count > 0
    # Validation error messages must be on a single line, among other restrictions.
    # See https://github.com/hashicorp/terraform/issues/24123
    error_message = "The `subnets_per_az` value must be greater than 0."
  }
}

variable "subnets_per_az_names" {
  type = list(string)

  description = <<-EOT
    The subnet names of each type (public or private) to provision per Availability Zone.
    This variable is optional.
    If a list of names is provided, the list items will be used as keys in the outputs `named_private_subnets_map`, `named_public_subnets_map`,
    `named_private_route_table_ids_map` and `named_public_route_table_ids_map`
    EOT
  default     = ["common"]
}

variable "default_nacls_enabled" {
  type        = bool
  description = "Enable or disable the default NACLs. Disable them to use custom NACLs."
  default     = true
}
