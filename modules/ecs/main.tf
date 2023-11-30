# ECS Resource
# Create local variable called instance_type
locals {
  instance_type = "inf2.xlarge"
}

resource "aws_ecs_cluster" "discord" {
  name = var.project_id
}

resource "aws_ecr_repository" "ecr" {
  name                 = var.project_id
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_lifecycle_policy" "foopolicy" {
  repository = aws_ecr_repository.ecr.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep only one untagged image, expire all others",
            "selection": {
                "tagStatus": "untagged",
                "countType": "imageCountMoreThan",
                "countNumber": 1
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}



data "aws_kms_key" "ebs" {
  key_id = "alias/aws/ebs"
}


# Found that the ECS ami with neuron did not work with huggingface container. Unsure why. 
# Ran into memory errors while downloading model to neuron device.
# EC2 Launch Template with Neuron drivers and ECS Drivers
# Make sure your aws config is setup with the region you want to deploy!
data "aws_ssm_parameter" "ecs_inf2_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/inf/recommended/image_id"
}

resource "aws_launch_template" "discord_diffusion" {
  name = var.project_id

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 80
      iops = 3000
      volume_type = "gp3"
      encrypted   = true
      kms_key_id  = data.aws_kms_key.ebs.arn
    }
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_discord.arn
  }

  image_id                             = data.aws_ssm_parameter.ecs_inf2_ami.value
  update_default_version               = true
  instance_initiated_shutdown_behavior = "terminate"

  # # Uncomment this if you are wanting to run spot instances for your GPU instances. Cost savings!
  #   instance_market_options {
  #     market_type = "spot"
  #   }

  instance_type = local.instance_type

  # If you want to ssh/login to your instances, reference your key pair here.
  # key_name = "YOUR KEY PAIR HERE"
  vpc_security_group_ids = [aws_security_group.ecs_discord.id]

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {cluster-id = aws_ecs_cluster.discord.id}))


  depends_on = [
    aws_ecs_cluster.discord,
    aws_security_group.ecs_discord
  ]

  tags = {
    Name = "${var.project_id}"
  }

}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Tier = "Public"
  }
}

resource "aws_security_group" "ecs_discord" {
  name        = "ECS-Discord-${var.project_id}"
  description = "Allow TLS inbound traffic"
  vpc_id      = var.vpc_id

  # # Be descriptive on the cidr_blocks of your ip address if you want to uncomment.
  #   ingress {
  #     description      = "SSH"
  #     from_port        = 22
  #     to_port          = 22
  #     protocol         = "tcp"
  #     cidr_blocks      = ["0.0.0.0/0"]
  #   }

  # ingress {
  #   description      = "EFS NFS ${var.project_id}"
  #   from_port        = 2049
  #   to_port          = 2049
  #   protocol         = "tcp"
  #   cidr_blocks      = ["0.0.0.0/0"]
  # }
}

resource "aws_vpc_security_group_ingress_rule" "nfs_efs" {
  security_group_id            = aws_security_group.ecs_discord.id
  referenced_security_group_id = aws_security_group.ecs_discord.id
  from_port                    = 2049
  ip_protocol                  = "tcp"
  to_port                      = 2049
}

resource "aws_vpc_security_group_egress_rule" "internet_out_ipv4" {
  security_group_id = aws_security_group.ecs_discord.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "internet_out_ipv6" {
  security_group_id = aws_security_group.ecs_discord.id
  ip_protocol       = "-1"
  cidr_ipv6         = "::/0"
}

# Role for ECS
resource "aws_iam_role" "ecs_discord" {
  name = "DiscordECS-${var.project_id}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ecs_discord" {
  name = "ECS-Discord-${var.project_id}"
  role = aws_iam_role.ecs_discord.name
}

resource "aws_iam_policy" "AWSLambdaSQSQueueExecutionRole" {
  name        = "AWSLambdaSQSQueueExecutionRole-${var.project_id}"
  path        = "/"
  description = "IAM policy for containers to query SQS queue"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",

        ],
        "Resource" : "arn:aws:sqs:${var.region}:${var.account_id}:${var.project_id}.fifo"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy" "AmazonEC2ContainerServiceforEC2Role" {
  name        = "AmazonEC2ContainerServiceforEC2Role-${var.project_id}"
  path        = "/"
  description = "IAM policy EC2 Container Service Role"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecs:Poll",
          "ecs:StartTelemetrySession",
          "ecr:GetDownloadUrlForLayer",
          "ecs:UpdateContainerInstancesState",
          "ecr:BatchGetImage",
          "ecs:RegisterContainerInstance",
          "ecs:Submit*",
          "ecs:DeregisterContainerInstance",
          "ecr:BatchCheckLayerAvailability"
        ],
        "Resource" : [
          "arn:aws:ecr:${var.region}:${var.account_id}:repository/${var.project_id}",
          "arn:aws:ecs:${var.region}:${var.account_id}:cluster/${var.project_id}",
          "arn:aws:ecs:${var.region}:${var.account_id}:container-instance/${var.project_id}/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ecs:DiscoverPollEndpoint",
          "logs:CreateLogStream",
          "ec2:DescribeTags",
          "ecs:CreateCluster",
          "ecr:GetAuthorizationToken",
          "logs:PutLogEvents"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AWSLambdaSQSQueueExecutionRole" {
  role       = aws_iam_role.ecs_discord.name
  policy_arn = resource.aws_iam_policy.AWSLambdaSQSQueueExecutionRole.arn
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerServiceforEC2Role" {
  role       = aws_iam_role.ecs_discord.name
  policy_arn = resource.aws_iam_policy.AmazonEC2ContainerServiceforEC2Role.arn
}

# ECS Task
resource "aws_iam_role" "ecs_execution" {
  name = "ecsExecution-${var.project_id}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "ssm_param_ecs" {
  name        = "ecs-ssm-${var.project_id}"
  path        = "/"
  description = "IAM policy for SSM Read variables"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:Decrypt",
          "ssm:GetParameters",
          "ssm:GetParameter"
        ],
        "Resource" : [
          "arn:aws:kms:*:${var.account_id}:alias/aws/ssm",
          "${aws_ssm_parameter.sqs_queue.arn}",
        ]
      }
    ]
  })
}



resource "aws_iam_policy" "ecslogs" {
  name        = "ecslogs-${var.project_id}"
  path        = "/"
  description = "awslogs permissions for ECS to CloudWatch"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "logs:PutLogEvents",
        "Resource" : "arn:aws:logs:${var.region}:${var.account_id}:log-group:ecs-${var.project_id}:log-stream:${var.project_id}"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ],
        "Resource" : "arn:aws:logs:${var.region}:${var.account_id}:log-group:ecs-${var.project_id}"
      }
    ]
  })
}

resource "aws_iam_policy" "AmazonECSTaskExecutionRolePolicy" {
  name        = "AmazonECSTaskExecutionRolePolicy-${var.project_id}"
  path        = "/"
  description = "IAM policy for ECS Task Execution"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ],
        "Resource" : "arn:aws:ecr:${var.region}:${var.account_id}:repository/${var.project_id}"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogStream",
          "ecr:GetAuthorizationToken",
          "logs:PutLogEvents"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonECSTaskExecutionRolePolicy" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = resource.aws_iam_policy.AmazonECSTaskExecutionRolePolicy.arn
}

resource "aws_iam_role_policy_attachment" "ecslogs" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = resource.aws_iam_policy.ecslogs.arn
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTask-${var.project_id}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AWSLambdaSQSQueueExecutionRole_ECS" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = resource.aws_iam_policy.AWSLambdaSQSQueueExecutionRole.arn
}

resource "aws_iam_role_policy_attachment" "ssm_param_ecs" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ssm_param_ecs.arn
}

### ECS Task
resource "aws_ecs_task_definition" "ecs_task" {
  # family                = "test"
  family                   = var.project_id
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = <<TASK_DEFINITION
  [
    {
        "name": "${var.project_id}",
        "image": "${aws_ecr_repository.ecr.repository_url}:latest",
        "cpu": 4096,
        "memory": 15600,
        "links": [],
        "portMappings": [],
        "essential": true,
        "entryPoint": [],
        "command": [],
        "environmentFiles": [],
        "mountPoints": [
                {
                    "sourceVolume": "efs-${var.project_id}",
                    "containerPath": "/mount/efs/models",
                    "readOnly": false
                }
            ],
        "volumesFrom": [],
        "secrets": [],
        "dnsServers": [],
        "dnsSearchDomains": [],
        "extraHosts": [],
        "dockerSecurityOptions": [],
        "dockerLabels": {},
        "ulimits": [],
        "systemControls": [],
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-create-group": "true",
                "awslogs-group": "ecs-${var.project_id}",
                "awslogs-region": "${var.region}",
                "awslogs-stream-prefix": "${var.project_id}"
            }
          },
          "linuxParameters": {
            "devices": [
              {
                "containerPath": "/dev/neuron0",
                "hostPath": "/dev/neuron0",
                "permissions": [
                  "read",
                  "write"
                ]
              }
            ],               
            "capabilities": {
              "add": [
                "IPC_LOCK"
              ]
            }
          },
          "placement_constraints": {
            "type": "memberOf",
            "expression": "attribute:ecs.instance-type == ${local.instance_type}"
          }
    }
  ]
  TASK_DEFINITION

  volume {
    name = "efs-${var.project_id}"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.ecs-task.id
      root_directory     = "/"
      transit_encryption = "ENABLED"
    }
  }

  depends_on = [
    aws_iam_role.ecs_task_role,
    aws_iam_role.ecs_execution
  ]
}

resource "aws_cloudwatch_log_group" "ecs_logging" {
  name              = "ecs-${var.project_id}"
  retention_in_days = 7
}

resource "aws_ssm_parameter" "sqs_queue" {
  name        = "/discord_diffusion/SQS_QUEUE"
  type        = "String"
  description = "SQS Queue url for ${var.project_id}"
  value       = var.sqs_queue_url
}

### ECS Service ###
resource "aws_ecs_service" "discord_diffusion" {
  name            = var.project_id
  cluster         = aws_ecs_cluster.discord.id
  task_definition = aws_ecs_task_definition.ecs_task.arn
  desired_count   = 0

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}

### EFS Volume ###
resource "aws_efs_file_system" "ecs-task" {
  creation_token = var.project_id
  encrypted      = true
  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }
  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }
}

# EFS Mount Targets
resource "aws_efs_mount_target" "efs_task_a" {
  file_system_id  = aws_efs_file_system.ecs-task.id
  subnet_id       = var.subnet_a_id
  security_groups = [aws_security_group.ecs_discord.id]
}

resource "aws_efs_mount_target" "efs_task_b" {
  file_system_id  = aws_efs_file_system.ecs-task.id
  subnet_id       = var.subnet_b_id
  security_groups = [aws_security_group.ecs_discord.id]
}

resource "aws_efs_mount_target" "efs_task_c" {
  file_system_id  = aws_efs_file_system.ecs-task.id
  subnet_id       = var.subnet_c_id
  security_groups = [aws_security_group.ecs_discord.id]
}