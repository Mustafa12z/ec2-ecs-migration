# Standalone stack: create the ECR repositories FIRST, push images, then apply
# terraform/ecs-app (which references these repos via data sources).
module "ecr" {
  source = "../ecs-app/modules/ecr"

  name             = var.project_name
  repository_names = var.repository_names
  max_image_count  = var.max_image_count
  tags             = var.tags
}
