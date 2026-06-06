//*******************************************
// OUTPUTS
//*******************************************

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.moodle.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.moodle.name
}

output "rds_endpoint" {
  description = "RDS endpoint — used in Moodle database config"
  value       = aws_db_instance.moodle.address
}

output "efs_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.moodle.id
}

output "moodle_url" {
  description = "Moodle site URL — point your DNS CNAME to alb_dns_name"
  value       = "https://${var.production_url}"
}

output "deploy_command" {
  description = "Force new ECS deployment after pushing a new image"
  value       = "aws ecs update-service --cluster ${aws_ecs_cluster.moodle.name} --service ${aws_ecs_service.moodle.name} --force-new-deployment --region ${var.aws_region}"
}

output "exec_command" {
  description = "Open a shell in a running Moodle container"
  value       = "aws ecs execute-command --cluster ${aws_ecs_cluster.moodle.name} --task <TASK_ID> --container moodle --interactive --command /bin/bash --region ${var.aws_region}"
}
