
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "database_subnets" {
  value = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  value = module.vpc.database_subnet_group_name
}

output "aws_route53_private_zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "aws_route53_private_zone_arn" {
  value = aws_route53_zone.main.arn
}

output "project_domain" {
  value = var.project_domain
}