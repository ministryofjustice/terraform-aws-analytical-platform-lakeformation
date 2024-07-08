terraform {
  required_providers {
    aws = {

      source = "hashicorp/aws"
      configuration_aliases = [
        aws,
        aws.target
      ]
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.0"
    }
  }
}