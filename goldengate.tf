locals {
  goldengate_admin_password_effective = coalesce(var.goldengate_admin_password, var.mysql_admin_password)
}

resource "oci_golden_gate_deployment" "mysql_deployment" {
  count = var.goldengate_enabled ? 1 : 0

  compartment_id  = var.compartment_ocid
  display_name    = var.goldengate_deployment_display_name
  deployment_type = "DATABASE_MYSQL"
  subnet_id       = oci_core_subnet.private.id

  cpu_core_count          = var.goldengate_cpu_core_count
  is_auto_scaling_enabled = false

  ogg_data {
    deployment_name = var.goldengate_deployment_name
    admin_username  = var.goldengate_admin_username
    admin_password  = local.goldengate_admin_password_effective
  }

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    component   = "goldengate"
  }

  depends_on = [
    oci_mysql_mysql_db_system.green,
    oci_mysql_mysql_db_system.blue,
  ]

  timeouts {
    create = "90m"
    update = "90m"
    delete = "90m"
  }
}

resource "oci_golden_gate_connection" "mysql_green_connection" {
  count = var.goldengate_enabled ? 1 : 0

  compartment_id  = var.compartment_ocid
  display_name    = "${var.mysql_green_display_name}-Connection"
  connection_type = "MYSQL"
  technology_type = var.goldengate_mysql_technology_type
  description     = "GoldenGate connection to OCI MySQL Green DB system"

  host              = oci_mysql_mysql_db_system.green.ip_address
  port              = var.mysql_port
  database_name     = var.mysql_database_name
  security_protocol = var.goldengate_mysql_security_protocol
  username          = var.mysql_admin_username
  password          = var.mysql_admin_password
  trigger_refresh   = false

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    color       = "green"
  }

  depends_on = [oci_golden_gate_deployment.mysql_deployment]

  timeouts {
    create = "90m"
    update = "90m"
    delete = "90m"
  }
}

resource "oci_golden_gate_connection" "mysql_blue_connection" {
  count = var.goldengate_enabled ? 1 : 0

  compartment_id  = var.compartment_ocid
  display_name    = "${var.mysql_blue_display_name}-Connection"
  connection_type = "MYSQL"
  technology_type = var.goldengate_mysql_technology_type
  description     = "GoldenGate connection to OCI MySQL Blue DB system"

  host              = oci_mysql_mysql_db_system.blue.ip_address
  port              = var.mysql_port
  database_name     = var.mysql_database_name
  security_protocol = var.goldengate_mysql_security_protocol
  username          = var.mysql_admin_username
  password          = var.mysql_admin_password
  trigger_refresh   = false

  freeform_tags = {
    environment = var.mysql_blue_environment_tag
    color       = "blue"
  }

  depends_on = [
    oci_golden_gate_deployment.mysql_deployment,
    oci_golden_gate_connection.mysql_green_connection,
  ]

  timeouts {
    create = "90m"
    update = "90m"
    delete = "90m"
  }
}

resource "oci_golden_gate_connection_assignment" "mysql_connection_assignment" {
  count = var.goldengate_enabled ? 1 : 0

  connection_id    = oci_golden_gate_connection.mysql_green_connection[0].id
  deployment_id    = oci_golden_gate_deployment.mysql_deployment[0].id

  depends_on = [
    oci_golden_gate_deployment.mysql_deployment,
    oci_golden_gate_connection.mysql_green_connection,
  ]

  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
}

resource "oci_golden_gate_connection_assignment" "mysql_blue_connection_assignment" {
  count = var.goldengate_enabled ? 1 : 0

  connection_id    = oci_golden_gate_connection.mysql_blue_connection[0].id
  deployment_id    = oci_golden_gate_deployment.mysql_deployment[0].id

  depends_on = [
    oci_golden_gate_deployment.mysql_deployment,
    oci_golden_gate_connection.mysql_blue_connection,
    oci_golden_gate_connection_assignment.mysql_connection_assignment,
  ]

  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
}
