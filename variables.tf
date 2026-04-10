variable "compartment_id" {
  description = "OCI Compartment ID"
  type        = string
}

variable "fingerprint" {
  description = "The fingerprint of the key to use for signing"
  type        = string
}

variable "private_key_path" {
  description = "The path to the private key to use for signing"
  type        = string
}

variable "region" {
  description = "The region to connect to. Default: uk-london-1"
  type        = string
  default     = "uk-london-1"
}

variable "ssh_authorized_keys" {
  description = "List of authorized SSH keys"
  type        = list(string)
}

variable "tenancy_ocid" {
  description = "The tenancy OCID."
  type        = string
}

variable "user_ocid" {
  description = "The user OCID."
  type        = string
}

variable "control_plane_source_cidr" {
  description = "The source IP CIDR range from which access to the control plane will be allowed"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.control_plane_source_cidr, 0))
    error_message = "Must be a valid IP CIDR range"
  }
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

variable "ports_additional" {
  description = "Additional ports to allow ingress traffic from on the internet"
  type = list(object({
    protocol     = string,
    port         = number,
    backend_port = number,
    source_cidr  = string
  }))
  default = [
    { protocol = "TCP", port = 80, backend_port = 30080, source_cidr = "0.0.0.0/0" },
    { protocol = "TCP", port = 443, backend_port = 30443, source_cidr = "0.0.0.0/0" },
  ]

  validation {
    condition = alltrue([
      for p in var.ports_additional :
      (p.port > 0 && p.port <= 65535) &&
      (p.backend_port > 0 && p.backend_port <= 65535) &&
      contains(["ICMP", "ICMPv6", "TCP", "UDP"], p.protocol) &&
      can(cidrhost(p.source_cidr, 0))
    ])
    error_message = "Must contain only valid port numbers, CIDR ranges and protocols from [ICMP, ICMPv6, TCP, UDP]"
  }
}

variable "rfc1918_cidr_block" {
  # https://www.rfc-editor.org/rfc/rfc1918
  description = "The RFC 1918 private IP address space to use for VCN"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.rfc1918_cidr_block, 0))
    error_message = "Must be a valid IP CIDR range"
  }
}

variable "subnet_private_cidr" {
  description = "The IP subnet within the rfc1918_cidr_block to use for the private subnet"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_private_cidr, 0))
    error_message = "Must be a valid IP CIDR range"
  }
}

variable "subnet_public_cidr" {
  description = "The IP subnet within the rfc1918_cidr_block to use for the public subnet"
  type        = string
  default     = "10.0.0.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_public_cidr, 0))
    error_message = "Must be a valid IP CIDR range"
  }
}

variable "talos_version" {
  type        = string
  description = "The version of Talos Linux to install. It's recommended to pin this to avoid future version bumps in this project causing issues"
  default     = "1.12.6"
}

# Instances using the VM.Standard.E2.1.Micro shape can only be created in a
# single availability domain within a region (for instance, in the London
# region, they MUST go in DhmS:UK-LONDON-1-AD-2). This is a limitation enforced
# by OCI.
variable "worker_availability_domain" {
  description = "The availability domain number into which workers should be placed"
  type        = number
  default     = 2
}

