resource "oci_core_vcn" "cluster_network" {
  compartment_id = var.compartment_id

  cidr_blocks = [
    var.rfc1918_cidr_block
  ]

  display_name = "cluster-${var.dns_label}"
  dns_label    = var.dns_label
}

resource "oci_core_nat_gateway" "private_subnet_nat_gateway" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.cluster_network.id
  display_name   = "nat-gateway-${var.dns_label}"
}

resource "oci_core_route_table" "private_subnet_route_table" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.cluster_network.id
  display_name   = "private-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.private_subnet_nat_gateway.id
  }
}

resource "oci_core_subnet" "private_subnet" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.cluster_network.id
  cidr_block                 = var.subnet_private_cidr
  display_name               = "cluster-${var.dns_label}-private-subnet"
  prohibit_internet_ingress  = true
  prohibit_public_ip_on_vnic = true
  security_list_ids          = [resource.oci_core_security_list.allow_all_for_nsg_usage.id]
  route_table_id             = oci_core_route_table.private_subnet_route_table.id
}

resource "oci_core_subnet" "public_subnet" {
  compartment_id    = var.compartment_id
  vcn_id            = oci_core_vcn.cluster_network.id
  cidr_block        = var.subnet_public_cidr
  display_name      = "cluster-${var.dns_label}-public-subnet"
  security_list_ids = [resource.oci_core_security_list.allow_all_for_nsg_usage.id]
}

resource "oci_core_internet_gateway" "internet_gateway" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.cluster_network.id
  display_name   = "internet-gateway-${var.dns_label}"
  enabled        = true
}

resource "oci_core_default_route_table" "internet_route_table" {
  compartment_id             = var.compartment_id
  manage_default_resource_id = oci_core_vcn.cluster_network.default_route_table_id

  route_rules {
    network_entity_id = oci_core_internet_gateway.internet_gateway.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

