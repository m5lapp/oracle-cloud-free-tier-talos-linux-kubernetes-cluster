resource "null_resource" "machine_config" {
  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    # Alternatively, use a container image from https://github.com/siderolabs/talos/pkgs/container/talosctl/
    command = <<EOT
      export CONFIG_PATCH_FILE="${path.module}/patches/config-patch.yaml"
      export CONFIG_PATCH_CONTROL_PLANE_FILE="${path.module}/patches/config-patch-control-plane.yaml"
      export CONFIG_PATCH_WORKER_FILE="${path.module}/patches/config-patch-worker.yaml"
      export CONFIG_PATCH_FLAGS=""

      if test -f $${CONFIG_PATCH_FILE} && test -s $${CONFIG_PATCH_FILE}; then
          CONFIG_PATCH_FLAGS="$${CONFIG_PATCH_FLAGS} --config-patch @$${CONFIG_PATCH_FILE} "
      fi
      if test -f $${CONFIG_PATCH_CONTROL_PLANE_FILE} && test -s $${CONFIG_PATCH_CONTROL_PLANE_FILE}; then
          CONFIG_PATCH_FLAGS="$${CONFIG_PATCH_FLAGS} --config-patch-control-plane @$${CONFIG_PATCH_CONTROL_PLANE_FILE} "
      fi
      if test -f $${CONFIG_PATCH_WORKER_FILE} && test -s $${CONFIG_PATCH_WORKER_FILE}; then
          CONFIG_PATCH_FLAGS="$${CONFIG_PATCH_FLAGS} --config-patch-worker @$${CONFIG_PATCH_WORKER_FILE} "
      fi

      echo "CONFIG_PATCH_FLAGS: $${CONFIG_PATCH_FLAGS}"

      talosctl gen config \
          cluster-${var.dns_label} \
          https://${var.nlb_public_ip}:6443 \
          --additional-sans ${var.nlb_public_ip} \
          --force \
          --talos-version ${var.talos_version} \
          --with-docs=false \
          --with-examples=false \
          $${CONFIG_PATCH_FLAGS} \
          --output ${path.module}/config/
    EOT
  }

  # Validate the controlplane.yaml config file.
  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<EOT
      talosctl validate --mode cloud --config ${path.module}/config/controlplane.yaml
    EOT
  }

  # Validate the worker.yaml config file.
  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<EOT
      talosctl validate --mode cloud --config ${path.module}/config/worker.yaml
    EOT
  }

  triggers = {
    patch_files = sha256(join("", [
      fileexists("${path.module}/patches/config-patch.yaml") ? filesha256("${path.module}/patches/config-patch.yaml") : "",
      fileexists("${path.module}/patches/config-patch-control-plane.yaml") ? filesha256("${path.module}/patches/config-patch-control-plane.yaml") : "",
      fileexists("${path.module}/patches/config-patch-worker.yaml") ? filesha256("${path.module}/patches/config-patch-worker.yaml") : "",
    ]))
    talos_version = var.talos_version
  }
}

data "local_file" "talos_control_plane_config" {
  depends_on = [null_resource.machine_config]
  filename   = "${path.module}/config/controlplane.yaml"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

resource "oci_core_instance" "talos_instance_control_plane" {
  depends_on     = [data.local_file.talos_control_plane_config]
  count          = local.instance_config_control_plane.count
  compartment_id = var.compartment_id

  # Spread the instances across all of the available availability domains.
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[
    count.index % length(data.oci_identity_availability_domains.ads.availability_domains)
  ].name
  display_name = "control-plane-${count.index}"
  shape        = local.instance_config_control_plane.shape

  source_details {
    source_id               = oci_core_image.talos_custom_image["control_plane"].id
    source_type             = "image"
    boot_volume_size_in_gbs = 50
  }

  shape_config {
    memory_in_gbs = local.instance_config_control_plane.ram
    ocpus         = local.instance_config_control_plane.ocpus
  }

  create_vnic_details {
    subnet_id = var.subnet_private_id
    private_ip = cidrhost(
      var.subnet_private_cidr,
      count.index + local.instance_config_control_plane.ip_offset
    )
    assign_public_ip = false
    nsg_ids          = [var.nsg_control_plane_id]
  }

  launch_options {
    network_type = "PARAVIRTUALIZED"
  }

  metadata = {
    "user_data" = base64encode(data.local_file.talos_control_plane_config.content)
  }

  lifecycle {
    # TODO: UPDATE THIS.
    prevent_destroy = false
  }
}

resource "oci_network_load_balancer_backend" "add_instance_to_nlb_backend_set_kubectl" {
  count                    = length(oci_core_instance.talos_instance_control_plane)
  network_load_balancer_id = var.nlb_id
  backend_set_name         = var.nlb_backend_set_name_kubectl
  port                     = var.port_kubectl
  target_id                = oci_core_instance.talos_instance_control_plane[count.index].id
}

resource "oci_network_load_balancer_backend" "add_instance_to_nlb_backend_set_talosctl" {
  count                    = length(oci_core_instance.talos_instance_control_plane)
  network_load_balancer_id = var.nlb_id
  backend_set_name         = var.nlb_backend_set_name_talosctl
  port                     = var.port_talosctl
  target_id                = oci_core_instance.talos_instance_control_plane[count.index].id
}

resource "null_resource" "bootstrap_cluster" {
  depends_on = [
    oci_core_instance.talos_instance_control_plane,
    oci_network_load_balancer_backend.add_instance_to_nlb_backend_set_talosctl,
  ]

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<EOT
      talosctl --talosconfig ${path.module}/config/talosconfig config \
          endpoints ${var.nlb_public_ip}
    EOT
  }

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<EOT
      talosctl --talosconfig ${path.module}/config/talosconfig config \
          nodes ${join(" ", [for i in oci_core_instance.talos_instance_control_plane : i.private_ip])}
    EOT
  }

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<EOT
      talosctl --talosconfig ${path.module}/config/talosconfig bootstrap \
          --nodes ${oci_core_instance.talos_instance_control_plane[0].private_ip}
    EOT
  }

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<EOT
      talosctl --talosconfig ${path.module}/config/talosconfig kubeconfig \
          ${path.module}/config/kubeconfig \
          --nodes ${oci_core_instance.talos_instance_control_plane[0].private_ip}
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

