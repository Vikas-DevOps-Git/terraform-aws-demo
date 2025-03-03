provider "aws" {
  region = var.aws_region
  default_tags { tags = { Environment = "prod", ManagedBy = "terraform", ComplianceTag = "sox-compliant" } }
}

module "vpc" {
  source               = "../../modules/vpc"
  environment          = "prod"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  enable_nat_gateway   = true
}

module "iam" {
  source      = "../../modules/iam"
  environment = "prod"
  aws_region  = var.aws_region
}

module "eks" {
  source                   = "../../modules/eks"
  environment              = "prod"
  vpc_id                   = module.vpc.vpc_id
  private_subnet_ids       = module.vpc.private_subnet_ids
  cluster_role_arn         = module.iam.cluster_role_arn
  node_role_arn            = module.iam.node_role_arn
  kms_key_arn              = var.kms_key_arn
  kubernetes_version       = "1.29"
  on_demand_desired        = 3
  on_demand_max            = 10
  spot_desired             = 5
  spot_max                 = 20
}

module "alb" {
  source       = "../../modules/alb"
  environment  = "prod"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.public_subnet_ids
  internal     = false
  waf_acl_arn  = var.waf_acl_arn
}
