
output "ecr_frontend" {
  value = aws_ecr_repository.frontend.repository_url
}

output "ecr_backend" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecs_cluster_id_default" {
  value = module.ecs.ecs_cluster_id
}

output "ecs_cluster_arn_default" {
  value = module.ecs.ecs_cluster_arn
}

output "ecs_cluster_name_default" {
  value = module.ecs.ecs_cluster_name
}