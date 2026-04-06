resource "oci_core_default_security_list" "lock_down_default_sl" {
  manage_default_resource_id = oci_core_vcn.cluster_network.default_security_list_id

  # Omit the egress_security_rules and ingress_security_rules blocks so that the
  # default security list is neutralised and cannot be used. We will define our
  # own further down.
}

resource "oci_core_security_list" "allow_all_egress" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.cluster_network.id
  display_name   = "Allow all egress"

  egress_security_rules {
    protocol    = "all"
    description = "Allow all traffic to anywhere"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_security_list" "subnet_private_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.cluster_network.id
  display_name   = "Private subnet ingress security list"

  dynamic "ingress_security_rules" {
    for_each = local.ports_ingress

    content {
      protocol    = local.ip_protocol_numbers[ingress_security_rules.value.protocol]
      description = "Allow ingress from public subnet on port ${ingress_security_rules.value.port}"
      source      = var.subnet_public_cidr
      tcp_options {
        min = ingress_security_rules.value.port
        max = ingress_security_rules.value.port
      }
    }
  }
}

resource "oci_core_security_list" "subnet_public_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.cluster_network.id
  display_name   = "Public subnet ingress security list"

  dynamic "ingress_security_rules" {
    for_each = local.ports_ingress

    content {
      protocol    = local.ip_protocol_numbers[ingress_security_rules.value.protocol]
      description = "Allow ingress from internet on port ${ingress_security_rules.value.port}"
      source      = "0.0.0.0/0"
      tcp_options {
        min = ingress_security_rules.value.port
        max = ingress_security_rules.value.port
      }
    }
  }
}

