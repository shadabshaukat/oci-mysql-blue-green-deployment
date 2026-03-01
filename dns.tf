locals {
  private_dns_zone_name_normalized = trimsuffix(var.private_dns_zone_name, ".")
}

data "oci_dns_views" "private" {
  compartment_id = var.compartment_ocid
  scope          = "PRIVATE"
}

locals {
  private_dns_view_id_override = try(trimspace(var.private_dns_view_id), "")

  effective_private_dns_view_id = local.private_dns_view_id_override != "" ? local.private_dns_view_id_override : try(data.oci_dns_views.private.views[0].id, null)

  private_dns_enabled = local.effective_private_dns_view_id != null && local.effective_private_dns_view_id != ""
}

resource "oci_dns_zone" "private_mysql_zone" {
  count = local.private_dns_enabled ? 1 : 0

  compartment_id = var.compartment_ocid
  name           = "${local.private_dns_zone_name_normalized}."
  scope          = "PRIVATE"
  view_id        = local.effective_private_dns_view_id
  zone_type      = "PRIMARY"
}

resource "oci_dns_rrset" "nlb_app_main" {
  count = local.private_dns_enabled ? 1 : 0

  zone_name_or_id = oci_dns_zone.private_mysql_zone[0].id
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
  count = local.private_dns_enabled ? 1 : 0

  zone_name_or_id = oci_dns_zone.private_mysql_zone[0].id
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
  count = local.private_dns_enabled ? 1 : 0

  zone_name_or_id = oci_dns_zone.private_mysql_zone[0].id
  domain          = "${var.dns_nlb_green_hostname}.${local.private_dns_zone_name_normalized}"
  rtype           = "A"

  items {
    domain = "${var.dns_nlb_green_hostname}.${local.private_dns_zone_name_normalized}"
    rdata  = oci_mysql_mysql_db_system.green.ip_address
    rtype  = "A"
    ttl    = var.private_dns_record_ttl
  }
}
