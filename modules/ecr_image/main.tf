### Create ECR Repository. Create and upload image to ECR.
resource "aws_ecr_repository" "ecr" {
  name                 = "${var.project_id}"
  image_tag_mutability = "MUTABLE"
}

# Clone repo
resource "null_resource" "git_clone" {
  provisioner "local-exec" {
    command = <<-EOT
    git clone https://${var.git_username}:${var.git_password}@${var.git_link}
    docker build -t discord-diffusion discord-diffusion/
    EOT
    interpreter = ["/bin/bash", "-c"]
    working_dir = path.module
  }
  # TODO: Remove this later so we do not run it every time there is a tfa.
  triggers = {
    always_run = timestamp()
  }
}
