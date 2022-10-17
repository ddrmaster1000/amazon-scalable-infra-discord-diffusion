# The Primary Autoscaling Group
resource "aws_autoscaling_group" "asg" {
  name                      = "asg-${var.project_id}"
  max_size                  = 5
  min_size                  = 0
  health_check_grace_period = 0
  health_check_type         = "EC2"
  default_cooldown          = 600
  launch_template {
    id      = aws_launch_template.discord_diffusion.id
    version = "$Latest"
  }
  vpc_zone_identifier = toset(data.aws_subnets.public.ids)
}