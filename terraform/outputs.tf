output "public_subnet_ids" {
  value = [module.vpc.public_subnet_1_id, module.vpc.public_subnet_2_id]
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
