resource "oci_identity_compartment" "kenshoo" {
  compartment_id = var.tenancy_ocid
  name           = var.compartment_name
  description    = "Everything for the kenshoo platform, managed by Terraform."
  enable_delete  = true
}

resource "oci_core_vcn" "main" {
  compartment_id = oci_identity_compartment.kenshoo.id
  display_name   = "kenshoo-vcn"
  cidr_blocks    = [var.vcn_cidr]
  dns_label      = "kenshoo"
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = oci_identity_compartment.kenshoo.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "kenshoo-igw"
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = oci_identity_compartment.kenshoo.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "kenshoo-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

resource "oci_core_security_list" "public" {
  compartment_id = oci_identity_compartment.kenshoo.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "kenshoo-public-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # SSH: only from your own IP.
  ingress_security_rules {
    source   = var.admin_cidr
    protocol = "6"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Kubernetes API: only from your own IP.
  ingress_security_rules {
    source   = var.admin_cidr
    protocol = "6"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # ICMP "fragmentation needed": required for path MTU discovery.
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "1"
    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = oci_identity_compartment.kenshoo.id
  vcn_id                     = oci_core_vcn.main.id
  display_name               = "kenshoo-public-subnet"
  cidr_block                 = var.subnet_cidr
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false
}
