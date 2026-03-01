data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

locals {
  discovered_availability_domains = try(data.oci_identity_availability_domains.ads.availability_domains, [])
  effective_availability_domain   = var.availability_domain != null ? var.availability_domain : try(local.discovered_availability_domains[0].name, null)
}
