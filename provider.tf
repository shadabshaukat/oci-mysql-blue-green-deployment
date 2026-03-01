provider "oci" {
  auth                = var.oci_auth
  region              = var.region
  tenancy_ocid        = var.tenancy_ocid
  config_file_profile = var.oci_config_profile
}
