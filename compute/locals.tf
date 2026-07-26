locals {
  instance_config_control_plane = {
    arch           = "arm64"
    shape          = "VM.Standard.A1.Flex"
    image_url_hash = var.image_factory_url_hash_control_plane
    count          = 2
    ocpus          = 2
    ram            = 12
    # The offset in the subnet from which to start allocating IP addresses.
    ip_offset = 2
  }

  instance_config_worker = {
    arch           = "amd64"
    shape          = "VM.Standard.E2.1.Micro"
    image_url_hash = var.image_factory_url_hash_worker
    count          = var.worker_count
    ocpus          = 1
    ram            = 1
    # The offset in the subnet from which to start allocating IP addresses.
    ip_offset = 12
    # Instances using the VM.Standard.E2.1.Micro shape can only be created in a
    # single availability domain within a region (for instance, in the London
    # region, they MUST go in DhmS:UK-LONDON-1-AD-2). This is a limitation
    # enforced by OCI.
    availability_domain = var.worker_availability_domain
  }

  instances = tomap({
    control_plane = local.instance_config_control_plane,
    worker        = local.instance_config_worker,
  })
}

