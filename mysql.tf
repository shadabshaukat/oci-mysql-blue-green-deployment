data "oci_mysql_mysql_configurations" "default_for_shape" {
  compartment_id = var.compartment_ocid
  shape_name     = var.mysql_shape_name
  state          = "ACTIVE"
  type           = ["DEFAULT"]
}

locals {
  mysql_configuration_parent_id_override = try(trimspace(var.mysql_configuration_parent_id), "")

  mysql_configuration_parent_id_auto_ha = try([
    for c in data.oci_mysql_mysql_configurations.default_for_shape.configurations : c.id
    if (
      can(regex("(?i)\\.ha$", try(c.display_name, ""))) ||
      can(regex("(?i)high availability", try(c.description, "")))
    )
  ][0], null)

  mysql_configuration_parent_id_default_any = try(data.oci_mysql_mysql_configurations.default_for_shape.configurations[0].id, null)

  mysql_configuration_parent_id_effective = local.mysql_configuration_parent_id_override != "" ? local.mysql_configuration_parent_id_override : (
    local.mysql_configuration_parent_id_auto_ha != null ? local.mysql_configuration_parent_id_auto_ha : local.mysql_configuration_parent_id_default_any
  )
}

resource "oci_mysql_mysql_configuration" "shared_logical_replication" {
  count = var.mysql_shared_configuration_enabled ? 1 : 0

  compartment_id          = var.compartment_ocid
  shape_name              = var.mysql_shape_name
  display_name            = var.mysql_shared_configuration_display_name
  description             = var.mysql_shared_configuration_description
  parent_configuration_id = local.mysql_configuration_parent_id_effective

  variables {
    binlog_expire_logs_seconds    = var.mysql_config_binlog_expire_logs_seconds
    binlog_row_metadata           = var.mysql_config_binlog_row_metadata
    binlog_transaction_compression = var.mysql_config_binlog_transaction_compression
    replica_parallel_workers      = var.mysql_config_replica_parallel_workers
  }

  lifecycle {
    precondition {
      condition     = local.mysql_configuration_parent_id_effective != null
      error_message = "Unable to resolve parent MySQL configuration. Set mysql_configuration_parent_id explicitly for this tenancy/region."
    }
  }
}

resource "oci_mysql_mysql_db_system" "green" {
  compartment_id          = var.compartment_ocid
  availability_domain     = local.effective_availability_domain
  configuration_id        = var.mysql_shared_configuration_enabled ? oci_mysql_mysql_configuration.shared_logical_replication[0].id : null
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
  configuration_id        = var.mysql_shared_configuration_enabled ? oci_mysql_mysql_configuration.shared_logical_replication[0].id : null
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
