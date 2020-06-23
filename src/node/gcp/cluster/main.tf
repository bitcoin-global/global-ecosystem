#=======================================================================
# Terraform state will be stored in Google Bucket
terraform {
  backend "gcs" {
    bucket = "tf-bitcoin"
    prefix = "terraform/state"
  }
}

#=======================================================================
# Required vars
#=======================================================================
variable "PROJECT" {}
variable "GKE_CLUSTER" {}
variable "GKE_ZONE" {}

#=======================================================================
# Google Auth
#=======================================================================
provider "google-beta" {
  project = var.PROJECT
}

data "google_client_config" "default" {
}

#=======================================================================
# Private network
#=======================================================================
resource "google_compute_network" "bitcoin_network" {
  project = var.PROJECT
  name    = "bitcoin-network"
}

resource "google_compute_global_address" "private_ip_address" {
  project       = var.PROJECT
  name          = "bitcoin-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.bitcoin_network.self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.bitcoin_network.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

#=======================================================================
# Kubernetes cluster
#=======================================================================
resource "google_container_cluster" "eu_bitcoin_cluster" {
  project            = var.PROJECT
  name               = var.GKE_CLUSTER
  location           = var.GKE_ZONE
  initial_node_count = 1
  logging_service    = "logging.googleapis.com/kubernetes"      # logging.googleapis.com/kubernetes
  monitoring_service = "monitoring.googleapis.com/kubernetes"   # monitoring.googleapis.com/kubernetes

  depends_on = [google_service_networking_connection.private_vpc_connection]
  network    = google_compute_network.bitcoin_network.self_link
  node_config {
    machine_type = "n1-standard-1"
    disk_size_gb = "20"
    preemptible  = true

    taint {
      key    = "task"
      value  = "preemptive"
      effect = "NO_SCHEDULE"
    }
  }

  ip_allocation_policy {
  }

  timeouts {
    create = "30m"
    update = "40m"
  }
}
