terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 8.8.0"
    }
  }

  required_version = ">= 1.14.0"
}

provider "oci" {
  region           = var.region
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
}

module "network" {
  source = "./network/"
  providers = {
    oci = oci
  }

  compartment_id     = var.compartment_id
  rfc1918_cidr_block = var.rfc1918_cidr_block
  tenancy_ocid       = var.tenancy_ocid
}

module "compute" {
  source     = "./compute/"
  depends_on = [module.network]
  providers = {
    oci = oci
  }

  compartment_id       = var.compartment_id
  dns_label            = var.dns_label
  nlb_id               = module.network.nlb_id
  nlb_public_ip        = module.network.nlb_public_ip
  nsg_control_plane_id = module.network.nsg_control_plane_id
  nsg_worker_id        = module.network.nsg_worker_id
  port_kubectl         = var.port_kubectl
  port_talosctl        = var.port_talosctl
  subnet_private_cidr  = var.subnet_private_cidr
  subnet_private_id    = module.network.subnet_private_id
  subnet_public_cidr   = var.subnet_private_cidr
  talos_version        = var.talos_version
  tenancy_ocid         = var.tenancy_ocid

  nlb_backend_set_name_kubectl  = module.network.nlb_backend_set_name_kubectl
  nlb_backend_set_name_talosctl = module.network.nlb_backend_set_name_talosctl
}

