# VPC Module Configuration
module "vpc" {
  source = "./modules/vpc"

  aws_region            = var.aws_region
  vpc_cidr              = var.vpc_cidr
  public_subnet_1_cidr  = var.public_subnet_1_cidr
  public_subnet_2_cidr  = var.public_subnet_2_cidr
  private_subnet_1_cidr = var.private_subnet_1_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr
  availability_zone_1   = var.availability_zone_1
  availability_zone_2   = var.availability_zone_2
}

# EC2 Module Configuration
module "ec2" {
  source            = "./modules/ec2"
  subnet_id         = module.vpc.public_subnet_1_id
  vpc_id            = module.vpc.vpc_id
  key_name          = var.key_name
  security_group_id = module.vpc.security_group_id
}

# # EKS Module Configuration
# module "eks" {
#   source          = "./modules/eks"
#   cluster_name    = var.cluster_name
#   cluster_version = var.cluster_version
#   vpc_id          = module.vpc.vpc_id
#   subnet_ids      = module.vpc.private_subnet_ids # Use the correct output
#   environment     = var.environment

#   # Node group configuration is handled inside the EKS module (see eks_managed_node_groups in the module)
# }

