terraform {
  backend "s3" {
    bucket         = "openmoodle-terraform-state"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "openmoodle-terraform-locks"
  }
}
