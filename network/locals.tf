locals {
  ip_protocol_numbers = tomap({
    "ICMP"   = 1,
    "TCP"    = 6,
    "UDP"    = 17,
    "ICMPv6" = 58,
  })

  ports_control_plane = tomap({
    "TCP_${var.port_kubectl}" = {
      protocol     = "TCP",
      port         = var.port_kubectl,
      backend_port = var.port_kubectl
    },
    "TCP_${var.port_talosctl}" = {
      protocol     = "TCP",
      port         = var.port_talosctl,
      backend_port = var.port_talosctl
    },
  })

  ports_additional = tomap({
    for port in var.ports_additional : "${port.protocol}_${port.port}" => port
  })

  ports_all = merge(
    local.ports_control_plane,
    local.ports_additional,
  )
}

