data "aws_partition" "current" {}

locals {
  partition = data.aws_partition.current.partition
}

# ------------------------------------------------------------ ECS execution role
# Used by the ECS agent: pulls images from ECR, writes logs, and injects the
# RDS secret into the task at start-up.
resource "aws_iam_role" "task_execution" {
  name = "${var.name}-ecs-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "read-db-secret"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.db_secret_arn
    }]
  })
}

# ------------------------------------------------------------ ECS task role
# Assumed by the application containers at runtime. Kept minimal; extend if the
# app needs to call AWS APIs directly.
resource "aws_iam_role" "task" {
  name = "${var.name}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# ------------------------------------------------------------ CodeDeploy role
resource "aws_iam_role" "codedeploy" {
  name = "${var.name}-codedeploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "codedeploy_ecs" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# ------------------------------------------------------------ GitHub OIDC (CI/CD)
# NOTE: The GitHub OIDC provider and the "legacy-api-github-actions" role are
# intentionally NOT managed by this module. They were bootstrapped manually
# via the AWS CLI (see MIGRATION.md) so CI could run before the rest of this
# stack existed, and are kept out of Terraform state to avoid a chicken-and-egg
# apply ordering problem. If you want Terraform to own them going forward,
# re-add the aws_iam_openid_connect_provider / aws_iam_role / aws_iam_role_policy
# resources here and `terraform import` the existing AWS resources into state
# rather than letting Terraform try to create duplicates.
