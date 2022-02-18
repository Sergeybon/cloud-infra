
output "ecr_frontend" {
  value = aws_ecr_repository.ecr_frontend_repository.repository_url
}

output "ecr_backend" {
  value = aws_ecr_repository.ecr_backend_repository.repository_url
}