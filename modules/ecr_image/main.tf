### Create ECR Repository. Create and upload image to ECR.
resource "aws_ecr_repository" "ecr" {
  name                 = "ecr-${var.project_id}"
  image_tag_mutability = "MUTABLE"
}