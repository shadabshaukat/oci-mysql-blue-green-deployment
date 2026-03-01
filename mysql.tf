resource "oci_mysql_mysql_db_system" "green" {
  compartment_id          = var.compartment_ocid
  availability_domain     = local.effective_availability_domain
  subnet_id               = oci_core_subnet.private.id
  shape_name              = var.mysql_shape_name
  mysql_version           = var.mysql_green_version
  data_storage_size_in_gb = var.mysql_storage_size_in_gb
  admin_username          = var.mysql_admin_username
  admin_password          = var.mysql_admin_password
  hostname_label          = var.mysql_green_hostname_label
  display_name            = var.mysql_green_display_name
  description             = "MySQL HA Green (staging) environment"
  port                    = var.mysql_port
  port_x                  = var.mysql_port_x
  is_highly_available     = true

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    color       = "green"
    role        = "staging"
  }

  lifecycle {
    ignore_changes = [
      admin_username,
      admin_password,
    ]
  }
}

resource "oci_mysql_mysql_db_system" "blue" {
  compartment_id          = var.compartment_ocid
  availability_domain     = local.effective_availability_domain
  subnet_id               = oci_core_subnet.private.id
  shape_name              = var.mysql_shape_name
  mysql_version           = var.mysql_blue_version
  data_storage_size_in_gb = var.mysql_storage_size_in_gb
  admin_username          = var.mysql_admin_username
  admin_password          = var.mysql_admin_password
  hostname_label          = var.mysql_blue_hostname_label
  display_name            = var.mysql_blue_display_name
  description             = "MySQL HA Blue (production) environment"
  port                    = var.mysql_port
  port_x                  = var.mysql_port_x
  is_highly_available     = true

  freeform_tags = {
    environment = var.mysql_blue_environment_tag
    color       = "blue"
    role        = "production"
  }

  lifecycle {
    ignore_changes = [
      admin_username,
      admin_password,
    ]
  }
}
