resource "google_compute_disk" "bitcoin-disk" {
  project = var.project
  name    =  format("%s-%s", var.prefix, "disc")
  type    = "pd-standard"
  zone    = var.region_zone
  size    = "300"
}

module "gce-container" {
  source  = "terraform-google-modules/container-vm/google"
  version = "~> 2.0"

  container = {
    image   = var.image
    command = var.command
    args    = var.args
    env     = []
    tty: true

    volumeMounts = [
      {
        mountPath = var.mount_path
        name      = format("%s-%s", var.prefix, "disc")
        readOnly  = false
      },
    ]
  }

  volumes = [
    {
      name = format("%s-%s", var.prefix, "disc")

      gcePersistentDisk = {
        pdName = format("%s-%s", var.prefix, "disc")
        fsType = "ext4"
      }
    },
  ]

  restart_policy = "Always"
}

resource "google_compute_instance" "bitcoin-node" {
  project      = var.project
  zone         = var.region_zone
  name         = format("%s-%s", var.prefix, "node")
  machine_type = var.type
  
  tags = var.tags

  boot_disk {
    initialize_params {
      image = module.gce-container.source_image
    }
  }

  attached_disk {
    source      = google_compute_disk.bitcoin-disk.self_link
    device_name = format("%s-%s", var.prefix, "disc")
    mode        = "READ_WRITE"
  }

  labels = {
    container-vm = module.gce-container.vm_container_label
  }

  metadata = {
    gce-container-declaration = module.gce-container.metadata_value
    google-logging-enabled    = "true"
    google-monitoring-enabled = "true"
  }

  network_interface {
    network = "default"
    access_config {
    }
  }
}
