terraform {
  backend "s3" {
    bucket         = "bny-terraform-state-dev"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "bny-terraform-locks"
    encrypt        = true
    kms_key_id     = "alias/terraform-state-key"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.6.0"
}
