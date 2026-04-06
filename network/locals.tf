locals {
  ip_protocol_numbers = tomap({
    "ICMP"   = 1,
    "TCP"    = 6,
    "UDP"    = 17,
    "ICMPv6" = 58,
  })

  ports_ingress = concat(
    [
      { protocol = "TCP", port = var.port_kubectl },
      { protocol = "TCP", port = var.port_talosctl },
    ],
    var.ports_additional,
  )
}

