locals {
  private_dns_zone_name_normalized = trimsuffix(var.private_dns_zone_name, ".")
}

data "oci_core_vcn_dns_resolver_association" "main" {
  vcn_id = oci_core_vcn.main.id
}

data "oci_dns_resolver" "main" {
  resolver_id = data.oci_core_vcn_dns_resolver_association.main.dns_resolver_id
}

locals {
  effective_private_dns_view_id = coalesce(var.private_dns_view_id, data.oci_dns_resolver.main.default_view_id)
}

resource "oci_dns_zone" "private_mysql_zone" {
  compartment_id = var.compartment_ocid
  name           = "${local.private_dns_zone_name_normalized}."
  scope          = "PRIVATE"
  view_id        = local.effective_private_dns_view_id
  zone_type      = "PRIMARY"
}

resource "oci_dns_rrset" "nlb_app_main" {
  zone_name_or_id = oci_dns_zone.private_mysql_zone.id
  domain          = "${var.dns_nlb_app_hostname}.${local.private_dns_zone_name_normalized}"
  rtype           = "A"

  items {
    domain = "${var.dns_nlb_app_hostname}.${local.private_dns_zone_name_normalized}"
    rdata  = oci_network_load_balancer_network_load_balancer.mysql_private_nlb.ip_addresses[0].ip_address
    rtype  = "A"
    ttl    = var.private_dns_record_ttl
  }
}

resource "oci_dns_rrset" "nlb_app_blue" {
  zone_name_or_id = oci_dns_zone.private_mysql_zone.id
  domain          = "${var.dns_nlb_blue_hostname}.${local.private_dns_zone_name_normalized}"
  rtype           = "A"

  items {
    domain = "${var.dns_nlb_blue_hostname}.${local.private_dns_zone_name_normalized}"
    rdata  = oci_mysql_mysql_db_system.blue.ip_address
    rtype  = "A"
    ttl    = var.private_dns_record_ttl
  }
}

resource "oci_dns_rrset" "nlb_app_green" {
  zone_name_or_id = oci_dns_zone.private_mysql_zone.id
  domain          = "${var.dns_nlb_green_hostname}.${local.private_dns_zone_name_normalized}"
  rtype           = "A"

  items {
    domain = "${var.dns_nlb_green_hostname}.${local.private_dns_zone_name_normalized}"
    rdata  = oci_mysql_mysql_db_system.green.ip_address
    rtype  = "A"
    ttl    = var.private_dns_record_ttl
  }
}
