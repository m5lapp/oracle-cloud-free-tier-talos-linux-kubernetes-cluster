# Every VCN has a default security list to allow some basic, standard ingress
# traffic such as SSH and ICMP as well as all egress traffic. Here we neutralise
# this default policy by omitting the egress_security_rules and
# ingress_security_rules blocks so that the default security list is empty and
# all traffic is denied by default in any new subnets that get created.
resource "oci_core_default_security_list" "lock_down_default_security_list" {
  manage_default_resource_id = oci_core_vcn.cluster_network.default_security_list_id
}

# As traffic is on only allowed if both a security list (applies to the whole
# subnet) and a network security group (applies to individual vNICs) allows it,
# this security list is used to allow all traffic at the subnet level which will
# then be allowed or denied by the NSGs below.
resource "oci_core_security_list" "allow_all_for_nsg_usage" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.cluster_network.id
  display_name   = "allow-all-delegate-to-nsgs"

  # Allow everything here because we are delegating to the Network Security
  # Groups (NSGs) defined below.
  ingress_security_rules {
    protocol = "all"
    source   = "0.0.0.0/0"
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# Network Load Balancer network security group.

resource "oci_core_network_security_group" "nsg_nlb" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.cluster_network.id
  display_name   = "network-load-balancer"
}

resource "oci_core_network_security_group_security_rule" "nlb_ingress" {
  for_each = local.ports_all

  network_security_group_id = oci_core_network_security_group.nsg_nlb.id
  direction                 = "INGRESS"
  protocol                  = local.ip_protocol_numbers[each.value.protocol]
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = each.value.port
      max = each.value.port
    }
  }
}

# Control plane network security group.

resource "oci_core_network_security_group" "nsg_control_plane" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.cluster_network.id
  display_name   = "cluster-control-plane-nodes"
}

resource "oci_core_network_security_group_security_rule" "control_plane_egress" {
  network_security_group_id = oci_core_network_security_group.nsg_control_plane.id

  direction   = "EGRESS"
  protocol    = "all"
  destination = "0.0.0.0/0"
}

resource "oci_core_network_security_group_security_rule" "control_plane_ingress_from_nlb" {
  for_each = local.ports_all

  network_security_group_id = oci_core_network_security_group.nsg_control_plane.id
  direction                 = "INGRESS"
  protocol                  = local.ip_protocol_numbers[each.value.protocol]
  source                    = oci_core_network_security_group.nsg_nlb.id
  source_type               = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = each.value.backend_port
      max = each.value.backend_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "control_plane_internal" {
  network_security_group_id = oci_core_network_security_group.nsg_control_plane.id

  direction   = "INGRESS"
  protocol    = "all"
  source      = var.subnet_private_cidr
  source_type = "CIDR_BLOCK"
}

# Worker network security group.

resource "oci_core_network_security_group" "nsg_worker" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.cluster_network.id
  display_name   = "cluster-worker-nodes"
}

resource "oci_core_network_security_group_security_rule" "worker_egress" {
  network_security_group_id = oci_core_network_security_group.nsg_worker.id

  direction   = "EGRESS"
  protocol    = "all"
  destination = "0.0.0.0/0"
}

resource "oci_core_network_security_group_security_rule" "worker_ingress_from_nlb" {
  for_each = local.ports_additional

  network_security_group_id = oci_core_network_security_group.nsg_worker.id
  direction                 = "INGRESS"
  protocol                  = local.ip_protocol_numbers[each.value.protocol]
  source                    = oci_core_network_security_group.nsg_nlb.id
  source_type               = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = each.value.backend_port
      max = each.value.backend_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "worker_internal" {
  network_security_group_id = oci_core_network_security_group.nsg_worker.id

  direction   = "INGRESS"
  protocol    = "all"
  source      = var.subnet_private_cidr
  source_type = "CIDR_BLOCK"
}

