
output "ec2_public_ip" {
  description = "Public IP of the EC2 server"
  value       = aws_instance.app.public_ip
}

output "rds_endpoint" {
  description = "Private RDS endpoint"
  value       = aws_db_instance.mysql.address
}

output "backend_ecr_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_url" {
  value = aws_ecr_repository.frontend.repository_url
}
