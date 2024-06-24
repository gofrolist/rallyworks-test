provider "aws" {
  region = var.region
}

module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace  = "eg"
  stage      = "dev"
  name       = "rallyworks"
  attributes = ["cluster"]
  delimiter  = "-"

  tags = {
    "Environment" = "Dev",
    "Service"     = "EKS Cluster"
  }

  context = module.this.context
}

data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

locals {
  enabled = module.this.enabled

  private_ipv6_enabled = var.private_ipv6_enabled

  # The usage of the specific kubernetes.io/cluster/* resource tags below are required
  # for EKS and Kubernetes to discover and manage networking resources
  # https://aws.amazon.com/premiumsupport/knowledge-center/eks-vpc-subnet-discovery/
  # https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/deploy/subnet_discovery.md
  tags = { "kubernetes.io/cluster/${module.label.id}" = "shared" }

  # required tags to make ALB ingress work https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html
  public_subnets_additional_tags = {
    "kubernetes.io/role/elb" : 1
  }
  private_subnets_additional_tags = {
    "kubernetes.io/role/internal-elb" : 1
  }

  # Enable the IAM user creating the cluster to administer it,
  # without using the bootstrap_cluster_creator_admin_permissions option,
  # as a way to test the access_entry_map feature.
  # In general, this is not recommended. Instead, you should
  # create the access_entry_map statically, with the ARNs you want to
  # have access to the cluster. We do it dynamically here just for testing purposes.
  access_entry_map = {
    (data.aws_iam_session_context.current.issuer_arn) = {
      access_policy_associations = {
        ClusterAdmin = {}
      }
    },
    "arn:aws:iam::769906345927:user/evasilenko" = {
      access_policy_associations = {
        ClusterAdmin = {}
      }
    }
  }

  # https://docs.aws.amazon.com/eks/latest/userguide/managing-vpc-cni.html#vpc-cni-latest-available-version
  vpc_cni_addon = {
    addon_name               = "vpc-cni"
    addon_version            = null
    resolve_conflicts        = "OVERWRITE"
    service_account_role_arn = one(module.vpc_cni_eks_iam_role[*].service_account_role_arn)
  }

  addons = concat([
    local.vpc_cni_addon
  ], var.addons)
}

module "vpc" {
  source  = "cloudposse/vpc/aws"
  version = "2.2.0"

  ipv4_primary_cidr_block = "172.16.0.0/16"
  tags                    = merge(
    local.tags,
    module.label.tags
  )

  context = module.this.context
}

module "subnets" {
  source  = "cloudposse/dynamic-subnets/aws"
  version = "2.4.2"

  availability_zones      = var.availability_zones
  vpc_id                  = module.vpc.vpc_id
  igw_id                  = [module.vpc.igw_id]
  ipv4_enabled            = true
  ipv6_enabled            = true
  ipv6_egress_only_igw_id = [module.vpc.ipv6_egress_only_igw_id]
  ipv4_cidr_block         = [module.vpc.vpc_cidr_block]
  ipv6_cidr_block         = [module.vpc.vpc_ipv6_cidr_block]
  nat_gateway_enabled     = true
  nat_instance_enabled    = false
  route_create_timeout    = "5m"
  route_delete_timeout    = "10m"

  subnet_type_tag_key = "cpco.io/subnet/type"

  subnets_per_az_count = var.subnets_per_az_count
  subnets_per_az_names = var.subnets_per_az_names

  private_open_network_acl_enabled = var.default_nacls_enabled
  public_open_network_acl_enabled  = var.default_nacls_enabled

  tags = merge(
    local.tags,
    module.label.tags
  )
  context = module.this.context
}

module "eks_cluster" {
  source = "cloudposse/eks-cluster/aws"
  version = "4.2.0"

  subnet_ids                   = concat(module.subnets.private_subnet_ids, module.subnets.public_subnet_ids)
  kubernetes_version           = var.kubernetes_version
  oidc_provider_enabled        = var.oidc_provider_enabled
  enabled_cluster_log_types    = var.enabled_cluster_log_types
  cluster_log_retention_period = var.cluster_log_retention_period

  cluster_encryption_config_enabled                         = var.cluster_encryption_config_enabled
  cluster_encryption_config_kms_key_id                      = var.cluster_encryption_config_kms_key_id
  cluster_encryption_config_kms_key_enable_key_rotation     = var.cluster_encryption_config_kms_key_enable_key_rotation
  cluster_encryption_config_kms_key_deletion_window_in_days = var.cluster_encryption_config_kms_key_deletion_window_in_days
  cluster_encryption_config_kms_key_policy                  = var.cluster_encryption_config_kms_key_policy
  cluster_encryption_config_resources                       = var.cluster_encryption_config_resources

  addons            = local.addons
  addons_depends_on = [module.eks_node_group]

  access_entry_map = local.access_entry_map
  access_config = {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  # This is to test `allowed_security_group_ids` and `allowed_cidr_blocks`
  # In a real cluster, these should be some other (existing) Security Groups and CIDR blocks to allow access to the cluster
  allowed_security_group_ids = [module.vpc.vpc_default_security_group_id]
  allowed_cidr_blocks        = [module.vpc.vpc_cidr_block]

  kubernetes_network_ipv6_enabled = local.private_ipv6_enabled

  tags    = module.label.tags
  context = module.this.context

  cluster_depends_on = [module.subnets]
}

module "eks_node_group" {
  source  = "cloudposse/eks-node-group/aws"
  version = "2.12.0"

  subnet_ids        = module.subnets.private_subnet_ids
  cluster_name      = module.eks_cluster.eks_cluster_id
  instance_types    = var.instance_types
  desired_size      = var.desired_size
  min_size          = var.min_size
  max_size          = var.max_size
  kubernetes_labels = var.kubernetes_labels

  block_device_mappings = [{
    device_name           = "/dev/xvda"
    volume_type           = "gp3"
  }]

  tags    = module.label.tags
  context = module.this.context
}
