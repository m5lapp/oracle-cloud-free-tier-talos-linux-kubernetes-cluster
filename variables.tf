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

variable "dns_label" {
  description = "A descriptive DNS name for the cluster network, e.g. 'prod'"
  type        = string
  default     = "prod"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{1,48}$", var.dns_label))
    error_message = "Must be a 1 to 48 character alphanumeric string that begins with a letter"
  }
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
  }))
  default = [
    { protocol = "TCP", port = 80, backend_port = 30080 },
    { protocol = "TCP", port = 443, backend_port = 30443 },
  ]

  validation {
    condition = alltrue([
      for p in var.ports_additional :
      (p.port > 0 && p.port <= 65535) &&
      (p.backend_port > 0 && p.backend_port <= 65535) &&
      contains(["ICMP", "ICMPv6", "TCP", "UDP"], p.protocol)
    ])
    error_message = "Must contain only valid port numbers and protocols from [ICMP, ICMPv6, TCP, UDP]"
  }
}

variable "rfc1918_cidr_block" {
  # https://www.rfc-editor.org/rfc/rfc1918
  description = "The RFC 1918 private IP address space to use for VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_private_cidr" {
  description = "The IP subnet within the rfc1918_cidr_block to use for the private subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_public_cidr" {
  description = "The IP subnet within the rfc1918_cidr_block to use for the public subnet"
  type        = string
  default     = "10.0.0.0/24"
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

