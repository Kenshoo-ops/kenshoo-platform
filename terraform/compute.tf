data "oci_identity_availability_domains" "all" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "k3s" {
  count = var.create_instance ? 1 : 0

  compartment_id      = oci_identity_compartment.kenshoo.id
  availability_domain = data.oci_identity_availability_domains.all.availability_domains[var.availability_domain_index].name
  display_name        = "kenshoo-k3s"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    hostname_label   = "kenshoo-k3s"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  lifecycle {
    # A newer Ubuntu image appearing later must not force a rebuild.
    ignore_changes = [source_details[0].source_id]
  }
}
