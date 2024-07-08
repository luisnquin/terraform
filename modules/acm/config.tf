
terraform {
  required_version = ">= 1.8.1"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }

    aws = {
      version = "~> 4.0"
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
