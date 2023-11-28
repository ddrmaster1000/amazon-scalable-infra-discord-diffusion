output "ami" {
  value = data.aws_ssm_parameter.ecs_inf2_ami.value
}

output "asg_name" {
  value = aws_autoscaling_group.asg.name
}

output "asg_arn" {
  value = aws_autoscaling_group.asg.arn
}

output "ecr_registry_url" {
  value = aws_ecr_repository.ecr.repository_url
}

output "ecr_registry_arn" {
  value = aws_ecr_repository.ecr.arn
}

output "ecs_service_arn" {
  value = aws_ecs_service.discord_diffusion.id
}