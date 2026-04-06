# Load the image_metadata template file.
data "local_file" "image_metadata_template" {
  filename = "${path.module}/templates/image_metadata.json"
}

# Template the image_metadata.json file.
resource "local_file" "image_metadata_file" {
  for_each   = local.instances
  depends_on = [data.local_file.image_metadata_template]

  filename = "${path.module}/images/${each.value.arch}/image_metadata.json"
  content = templatefile(
    data.local_file.image_metadata_template.filename,
    {
      talos_version       = var.talos_version
      internal_shape_name = "${each.value.shape}"
    }
  )
  file_permission = "0644"
}

# We have to use a null_resource to download the Talos images as they are too
# large to fit in the buffers of a data source or resource local_file.
resource "null_resource" "talos_image_download" {
  for_each = local.instances

  provisioner "local-exec" {
    command = <<-EOT
      curl -L --silent \
          -o ${path.module}/images/${each.value.arch}/oracle-${each.value.arch}.gcow2 \
          'https://factory.talos.dev/image/${each.value.image_url_hash}/v${var.talos_version}/oracle-${each.value.arch}.qcow2'
    EOT
  }

  triggers = {
    arch                   = each.value.arch
    image_factory_url_hash = each.value.image_url_hash
    talos_version          = var.talos_version
  }
}

# Combine the image_metadata.json file and the downloaded talos boot image into
# an OCI format file for creating an image out of.
resource "null_resource" "talos_oci_image" {
  for_each   = local.instances
  depends_on = [local_file.image_metadata_file, null_resource.talos_image_download]

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<EOT
      tar -czvf ${path.module}/images/${each.value.arch}/oracle-${each.value.arch}.oci \
          -C ${dirname(local_file.image_metadata_file[each.key].filename)} \
          ${basename(local_file.image_metadata_file[each.key].filename)} \
          oracle-${each.value.arch}.gcow2
    EOT
  }

  triggers = {
    image_metadata_hash = sha256(local_file.image_metadata_file[each.key].content)
    # As the image file will not exist when Terraform first starts running,
    # Terraform won't allow it to be used as a trigger source because it
    # considers the apply stage to be inconsistent with the plan stage as the
    # file gets created in the meantime. Therefore, just use the
    # image_url_hash and talos_version variables which should always tie to a
    # specific downloaded image file.
    talos_image_hash = sha256(
      join("", [each.value.image_url_hash, var.talos_version])
    )
  }
}

# Get the object storage namespace for the desired compartment.
data "oci_objectstorage_namespace" "default_bucket_namespace" {
  compartment_id = var.compartment_id
}

# Create a new object storage bucket for storing the OCI images.
resource "oci_objectstorage_bucket" "instance_images" {
  compartment_id = var.compartment_id
  name           = "instance-images"
  namespace      = data.oci_objectstorage_namespace.default_bucket_namespace.namespace

  access_type  = "NoPublicAccess"
  auto_tiering = "Disabled"
}

resource "null_resource" "talos_oci_image_upload" {
  for_each = local.instances
  depends_on = [
    null_resource.talos_oci_image,
    oci_objectstorage_bucket.instance_images,
  ]

  provisioner "local-exec" {
    interpreter = ["/usr/bin/env", "bash", "-c"]
    command     = <<-EOT
      export OBJECT_NAME="talos-${var.talos_version}-oracle-${substr(each.value.image_url_hash, 0, 10)}-${each.value.arch}.oci"

      if oci os object get \
          --namespace "${data.oci_objectstorage_namespace.default_bucket_namespace.namespace}" \
          --bucket-name "${oci_objectstorage_bucket.instance_images.name}" \
          --name "$${OBJECT_NAME}" \
          > /dev/null 2>&1; then
        echo "Object $${OBJECT_NAME} already exists, skipping upload."
      else
        echo "Uploading $${OBJECT_NAME}..."
        oci os object put \
          --namespace "${data.oci_objectstorage_namespace.default_bucket_namespace.namespace}" \
          --bucket-name "${oci_objectstorage_bucket.instance_images.name}" \
          --name "$${OBJECT_NAME}" \
          --file "${path.module}/images/${each.value.arch}/oracle-${each.value.arch}.oci"
      fi
    EOT
  }

  triggers = {
    image_metadata_hash = sha256(local_file.image_metadata_file[each.key].content)
    talos_image_hash = sha256(
      join("", [each.value.image_url_hash, var.talos_version])
    )
  }
}

resource "oci_core_image" "talos_custom_image" {
  for_each   = local.instances
  depends_on = [null_resource.talos_oci_image_upload]

  compartment_id = var.compartment_id
  display_name   = "talos-linux-${var.talos_version}-${each.value.arch}"
  launch_mode    = "PARAVIRTUALIZED"

  image_source_details {
    operating_system         = "Talos Linux"
    operating_system_version = var.talos_version

    source_type    = "objectStorageTuple"
    namespace_name = data.oci_objectstorage_namespace.default_bucket_namespace.namespace
    bucket_name    = oci_objectstorage_bucket.instance_images.name
    object_name    = "talos-${var.talos_version}-oracle-${substr(each.value.image_url_hash, 0, 10)}-${each.value.arch}.oci"
  }

  freeform_tags = {
    "architecture"           = each.value.arch
    "image_factory_url_hash" = each.value.image_url_hash
    "version"                = var.talos_version
  }

  timeouts {
    create = "20m"
  }
}

