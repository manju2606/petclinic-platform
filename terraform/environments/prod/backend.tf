# Partial backend config — bucket name requires the AWS account ID.
# After running scripts/bootstrap-state.sh, initialise with:
#   terraform init -backend-config="bucket=petclinic-terraform-state-$(aws sts get-caller-identity --query Account --output text)"
terraform {
  backend "s3" {
    key            = "petclinic/prod/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "petclinic-terraform-locks"
  }
}
