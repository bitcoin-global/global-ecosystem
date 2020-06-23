#=======================================================================
# Terraform state will be stored in Google Bucket
# Comment to use local state
terraform {
  backend "gcs" {
    bucket = "tf-bitcoin"
    prefix = "terraform/state"
  }
}

provider "google" {
 region = var.region
}
