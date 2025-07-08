

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "= 6.42.0"
    }
     aws = {
      source  = "hashicorp/aws"
      version = ">= 5.8.0"
    }

    docker = {
      source  = "kreuzwerker/docker"
            version = "~> 3.0"
    }
  }


  required_version = "~> 1.7"

  backend "s3" {
    encrypt        = true
  }
}