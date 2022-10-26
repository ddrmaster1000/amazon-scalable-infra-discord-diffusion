# ECS Resource
# This assumes you already have ECR setup and the image placed in ECR.
resource "aws_ecs_cluster" "discord" {
  name = var.project_id
}

resource "aws_ecr_repository" "ecr" {
  name                 = var.project_id
  image_tag_mutability = "MUTABLE"
  force_delete         = true
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

# EC2 Launch Template with Nvidia drivers and ECS Drivers
# Make sure your aws config is setup with the region you want to deploy!
data "aws_ssm_parameter" "ecs_gpu_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended/image_id"
}

resource "aws_launch_template" "discord_diffusion" {
  name = var.project_id

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 40
      volume_type = "gp3"
    }
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_discord.arn
  }

  image_id = data.aws_ssm_parameter.ecs_gpu_ami.value

  instance_initiated_shutdown_behavior = "terminate"

  # # Uncomment this if you are wanting to run spot instances for your GPU instances. Cost savings!
  #   instance_market_options {
  #     market_type = "spot"
  #   }

  instance_type = "g4dn.xlarge"

  # If you want to ssh/login to your instances, reference your key pair here.
  # key_name = "YOUR KEY PAIR HERE"
  vpc_security_group_ids = [aws_security_group.ecs_discord.id]

  user_data = base64encode(
    <<EOT
    #!/bin/bash
    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${aws_ecs_cluster.discord.id}
    ECS_ENABLE_GPU_SUPPORT=true
    EOF
    EOT
  )

  depends_on = [
    aws_ecs_cluster.discord,
    aws_security_group.ecs_discord
  ]
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

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
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

data "aws_iam_policy" "AWSLambdaSQSQueueExecutionRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

data "aws_iam_policy" "AmazonEC2ContainerServiceforEC2Role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "AWSLambdaSQSQueueExecutionRole" {
  role       = aws_iam_role.ecs_discord.name
  policy_arn = data.aws_iam_policy.AWSLambdaSQSQueueExecutionRole.arn
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerServiceforEC2Role" {
  role       = aws_iam_role.ecs_discord.name
  policy_arn = data.aws_iam_policy.AmazonEC2ContainerServiceforEC2Role.arn
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

data "aws_iam_policy" "AmazonECSTaskExecutionRolePolicy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "AmazonECSTaskExecutionRolePolicy" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = data.aws_iam_policy.AmazonECSTaskExecutionRolePolicy.arn
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
  policy_arn = data.aws_iam_policy.AWSLambdaSQSQueueExecutionRole.arn
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
        "memory": 12288,
        "links": [],
        "portMappings": [],
        "essential": true,
        "entryPoint": [],
        "command": [],
        "environment": [
            {
                "name": "SQSQUEUEURL",
                "value": "${var.sqs_queue_url}"
            },
            {
                "name": "REGION",
                "value": "${var.region}"
            }
        ],
        "environmentFiles": [],
        "mountPoints": [],
        "volumesFrom": [],
        "secrets": [],
        "dnsServers": [],
        "dnsSearchDomains": [],
        "extraHosts": [],
        "dockerSecurityOptions": [],
        "dockerLabels": {},
        "ulimits": [],
        "systemControls": [],
        "resourceRequirements": [
            {
                "value": "1",
                "type": "GPU"
            }
        ]
    }
  ]
  TASK_DEFINITION

  depends_on = [
    aws_iam_role.ecs_task_role,
    aws_iam_role.ecs_execution
  ]
}

### ECS Service ###
resource "aws_ecs_service" "discord_diffusion" {
  name            = var.project_id
  cluster         = aws_ecs_cluster.discord.id
  task_definition = aws_ecs_task_definition.ecs_task.arn
  # desired_count   = 0

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}