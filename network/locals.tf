locals {
  ip_protocol_numbers = tomap({
    "ICMP"   = 1,
    "TCP"    = 6,
    "UDP"    = 17,
    "ICMPv6" = 58,
  })

  ports_control_plane = [
    { protocol = "TCP", port = var.port_kubectl },
    { protocol = "TCP", port = var.port_talosctl },
  ]

  ports_ingress = concat(
    local.ports_control_plane,
    var.ports_additional,
  )
}

