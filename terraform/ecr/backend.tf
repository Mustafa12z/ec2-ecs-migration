# Remote state backend (partial configuration).
# Uses a different state key from the ecs-app stack so they never collide:
#
#   terraform init -backend-config=backend.hcl
#
# See backend.hcl.example.
terraform {
  backend "s3" {}
}
