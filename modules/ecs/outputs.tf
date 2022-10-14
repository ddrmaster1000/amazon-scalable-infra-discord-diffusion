output "ami" {
  value = data.aws_ssm_parameter.ecs_gpu_ami.value
}

output "launch_template" {
  value = aws_launch_template.discord_diffusion
}

output "ecs_cluster_id" {
  value = aws_ecs_cluster.discord.id
}

output "ecs_task_arn" {
  value = aws_ecs_task_definition.ecs_task.arn
}