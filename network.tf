data "oci_core_services" "all" {}

locals {
  project_prefix = var.project_prefix
}

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_block     = var.vcn_cidr
  display_name   = "${local.project_prefix}-vcn"
  dns_label      = "mysqlvcn"

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    component   = "network"
  }
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.project_prefix}-igw"
  enabled        = true

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    component   = "network"
  }
}

resource "oci_core_nat_gateway" "nat" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.project_prefix}-nat"

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    component   = "network"
  }
}

resource "oci_core_service_gateway" "sgw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.project_prefix}-sgw"

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    component   = "network"
  }

  services {
    service_id = data.oci_core_services.all.services[0].id
  }
}

resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.project_prefix}-public-rt"

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    component   = "network"
  }

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_route_table" "private_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.project_prefix}-private-rt"

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    component   = "network"
  }

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat.id
  }

  route_rules {
    destination       = data.oci_core_services.all.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.sgw.id
  }
}

resource "oci_core_security_list" "public_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.project_prefix}-public-sl"

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    component   = "network"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_security_list" "private_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.project_prefix}-private-sl"

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    component   = "network"
  }

  ingress_security_rules {
    protocol = "6"
    source   = var.public_subnet_cidr
    tcp_options {
      min = var.mysql_port
      max = var.mysql_port
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = var.private_subnet_cidr
    tcp_options {
      min = var.mysql_port
      max = var.mysql_port_x
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = var.vcn_cidr
    tcp_options {
      min = 443
      max = 443
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_subnet" "public_bastion" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "${local.project_prefix}-public-bastion-subnet"
  dns_label                  = "publicbastion"
  route_table_id             = oci_core_route_table.public_rt.id
  security_list_ids          = [oci_core_security_list.public_sl.id]
  prohibit_public_ip_on_vnic = false

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    component   = "network"
  }
}

resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.private_subnet_cidr
  display_name               = "${local.project_prefix}-private-subnet"
  dns_label                  = "private"
  route_table_id             = oci_core_route_table.private_rt.id
  security_list_ids          = [oci_core_security_list.private_sl.id]
  prohibit_public_ip_on_vnic = true

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    component   = "network"
  }
}
