//*******************************************
// ECR — Container Registry
//*******************************************

resource "aws_ecr_repository" "moodle" {
  name                 = "${var.client_name}/moodle"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = { Name = "${var.client_name}_moodle_ecr" }
}

// Lifecycle policy — keep last 10 tagged images, remove untagged after 1 day
resource "aws_ecr_lifecycle_policy" "moodle" {
  repository = aws_ecr_repository.moodle.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}

output "ecr_repository_url" {
  description = "Push your Moodle image to this URI, then set moodle_image variable"
  value       = aws_ecr_repository.moodle.repository_url
}
