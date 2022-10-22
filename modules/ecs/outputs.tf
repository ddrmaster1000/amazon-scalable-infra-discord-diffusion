output "ami" {
  value = data.aws_ssm_parameter.ecs_gpu_ami.value
}

output "asg_name" {
  value = aws_autoscaling_group.asg.name
}

output "ecr_registry_url" {
  value     = aws_ecr_repository.ecr.repository_url
}
