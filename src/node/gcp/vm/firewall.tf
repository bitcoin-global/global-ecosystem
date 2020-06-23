resource "google_compute_firewall" "bitcoin_network" {
  project = var.project
  name    = format("%s-%s", var.prefix, "network")
  network = "default"

  allow {
    protocol = "tcp"
    ports    = var.expose_ports
  }

  source_tags = ["bitcoin-node"]
}
