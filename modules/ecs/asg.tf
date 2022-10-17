# The Primary Autoscaling Group

resource "aws_autoscaling_group" "asg" {
  name                      = "asg-${var.project_id}"
  max_size                  = 5
  min_size                  = 0
  health_check_grace_period = 0
  health_check_type         = "EC2"
  launch_template {
    id      = aws_launch_template.discord_diffusion.id
    version = "$Latest"
  }
  vpc_zone_identifier = toset(data.aws_subnets.public.ids)
}

# resource "aws_autoscaling_policy" "scale_down" {
#   name = "scale-down-${var.project_id}"
#   autoscaling_group_name = aws_autoscaling_group.asg.name
#   adjustment_type = "ChangeInCapacity"
#   policy_type = "StepScaling"

#   step_adjustment {
#     scaling_adjustment          = -1
#     metric_interval_upper_bound = -1.0
#   }
# }


# ## TODO: IDK what terrible person made step scaling so confusing. They suck.
# resource "aws_appautoscaling_target" "ecs_target" {
#   max_capacity       = 5
#   min_capacity       = 0
#   resource_id        = "service/${var.project_id}/${var.project_id}"
#   scalable_dimension = "ecs:service:DesiredCount"
#   service_namespace  = "ecs"
# }

# resource "aws_appautoscaling_policy" "ecs_policy" {
#   name               = "scale-down"
#   policy_type        = "StepScaling"
#   resource_id        = aws_appautoscaling_target.ecs_target.resource_id
#   scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

#   step_scaling_policy_configuration {
#     adjustment_type         = "ChangeInCapacity"
#     cooldown                = 600
#     metric_aggregation_type = "Maximum"

#     step_adjustment {
#       metric_interval_upper_bound = 0
#       scaling_adjustment          = -1
#     }
#   }
# }