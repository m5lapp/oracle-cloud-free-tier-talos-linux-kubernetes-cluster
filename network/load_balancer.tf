resource "oci_network_load_balancer_network_load_balancer" "cluster_nlb" {
  compartment_id = var.compartment_id
  depends_on = [
    oci_core_network_security_group.nsg_nlb,
    oci_core_subnet.public_subnet,
  ]

  subnet_id    = oci_core_subnet.public_subnet.id
  display_name = "cluster-${var.dns_label}-network-load-balancer"

  # Give the load balancer a public IP address.
  is_private = false
  # Do not preserve the client IP and port details so we do not have to worry
  # about routing responses back out to clients, they will automatically go via
  # the network load balancer.
  is_preserve_source_destination = false

  network_security_group_ids = [oci_core_network_security_group.nsg_nlb.id]
}

resource "oci_network_load_balancer_backend_set" "backend_kubectl" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.cluster_nlb.id
  name                     = "kubectl-backend-set"

  # Use just the destination and source IPs for load balancing.
  policy             = "TWO_TUPLE"
  is_preserve_source = false

  health_checker {
    protocol           = "HTTPS"
    port               = var.port_kubectl
    interval_in_millis = 10000
    timeout_in_millis  = 3000
    return_code        = 401
    url_path           = "/readyz"
  }
}

resource "oci_network_load_balancer_backend_set" "backend_talosctl" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.cluster_nlb.id
  name                     = "talosctl-backend-set"

  # Use just the destination and source IPs for load balancing.
  policy             = "TWO_TUPLE"
  is_preserve_source = false

  health_checker {
    protocol           = "TCP"
    port               = var.port_talosctl
    interval_in_millis = 10000
    timeout_in_millis  = 3000
  }
}

resource "oci_network_load_balancer_backend_set" "backend_additional" {
  for_each                 = local.ports_additional
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.cluster_nlb.id
  name                     = "${each.key}-backend-set"

  # Use just the destination and source IPs for load balancing.
  policy             = "TWO_TUPLE"
  is_preserve_source = false

  health_checker {
    protocol           = each.value.protocol
    port               = each.value.backend_port
    interval_in_millis = 10000
    timeout_in_millis  = 3000
  }
}

resource "oci_network_load_balancer_listener" "listener_kubectl" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.cluster_nlb.id
  default_backend_set_name = oci_network_load_balancer_backend_set.backend_kubectl.name
  name                     = "kubectl-port-${var.port_kubectl}"

  port     = var.port_kubectl
  protocol = "TCP"
}

resource "oci_network_load_balancer_listener" "listener_talosctl" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.cluster_nlb.id
  default_backend_set_name = oci_network_load_balancer_backend_set.backend_talosctl.name
  name                     = "talosctl-port-${var.port_talosctl}"

  port     = var.port_talosctl
  protocol = "TCP"
}

resource "oci_network_load_balancer_listener" "listener_additional" {
  for_each = local.ports_additional

  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.cluster_nlb.id
  default_backend_set_name = oci_network_load_balancer_backend_set.backend_additional[each.key].name
  name                     = "backend-port-${each.value.protocol}-${each.value.backend_port}"

  port     = each.value.port
  protocol = each.value.protocol
}

