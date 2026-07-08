# Remote state backend (partial configuration).
#
# The bucket / table names are NOT hardcoded here because backend blocks
# cannot use variables. Supply them at init time with your existing bucket:
#
#   terraform init -backend-config=backend.hcl
#
# See backend.hcl.example for the required keys.
terraform {
  backend "s3" {}
}
