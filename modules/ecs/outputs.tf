output "ami" {
  value = data.aws_ssm_parameter.ecs_gpu_ami.value
}
