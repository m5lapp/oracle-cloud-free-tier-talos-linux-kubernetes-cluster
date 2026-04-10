variable "compartment_id" {
  description = "OCI Compartment ID"
  type        = string
}

variable "dns_label" {
  description = "A descriptive DNS name for the cluster network, e.g. 'prod'"
  type        = string
  default     = "prod"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{1,48}$", var.dns_label))
    error_message = "Must be a 1 to 48 character alphanumeric string that begins with a letter"
  }
}

variable "image_factory_url_hash_control_plane" {
  type        = string
  description = "The identifying hash of the disk image from image factory for the control plane"
  default     = "613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245"
}

variable "image_factory_url_hash_worker" {
  type        = string
  description = "The identifying hash of the disk image from image factory for the workers"
  default     = "613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245"
}

variable "nlb_backend_set_name_kubectl" {
  description = "The name of the network load balancer backend set for kubectl"
  type        = string
}

variable "nlb_backend_set_name_talosctl" {
  description = "The name of the network load balancer backend set for talosctl"
  type        = string
}

variable "nlb_backend_sets_additional" {
  description = "Additional network load balancer backend sets for ingress"
  type = map(object({
    backend_set_name = string,
    backend_port     = number,
  }))
}

variable "nlb_id" {
  type        = string
  description = "The resource ID of the cluster network load balancer"
}

variable "nlb_public_ip" {
  type        = string
  description = "The public IP address of the cluster network load balancer"
}

variable "nsg_control_plane_id" {
  description = "The Network Security Groups for private subnet members"
  type        = string
}

variable "nsg_worker_id" {
  description = "The Network Security Groups for public subnet members"
  type        = string
}

variable "port_kubectl" {
  description = "The TCP port number to use for kubectl"
  type        = number
  default     = 6443

  validation {
    condition     = var.port_kubectl > 0 && var.port_kubectl <= 65535
    error_message = "Must be a valid TCP port number"
  }
}

variable "port_talosctl" {
  description = "The TCP port number to use for Talos' API server"
  type        = number
  default     = 50000

  validation {
    condition     = var.port_talosctl > 0 && var.port_talosctl <= 65535
    error_message = "Must be a valid TCP port number"
  }
}

variable "subnet_private_cidr" {
  description = "The IP subnet within the rfc1918_cidr_block to use for the private subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_private_id" {
  description = "The ID of the private subnet within the rfc1918_cidr_block"
  type        = string
}

variable "subnet_public_cidr" {
  description = "The IP subnet within the rfc1918_cidr_block to use for the public subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "talos_version" {
  type        = string
  description = "The version of Talos to install. It's recommended to pin this to avoid future version bumps in this project causing issues"
  default     = "1.12.6"
}

variable "tenancy_ocid" {
  description = "The tenancy OCID"
  type        = string
}

variable "worker_availability_domain" {
  description = "The availability domain number into which workers should be placed"
  type        = number
  default     = 2
}

