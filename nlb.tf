resource "oci_network_load_balancer_network_load_balancer" "mysql_private_nlb" {
  compartment_id                 = var.compartment_ocid
  display_name                   = "MySQL-NLB"
  subnet_id                      = oci_core_subnet.private.id
  is_private                     = true
  is_preserve_source_destination = false

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    component   = "nlb"
  }
}

resource "oci_network_load_balancer_backend_set" "mysql_bs" {
  name                     = "mysql-backend-set"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.mysql_private_nlb.id
  policy                   = "FIVE_TUPLE"

  health_checker {
    protocol = "TCP"
    port     = var.mysql_port
  }
}

resource "oci_network_load_balancer_backend" "mysql_green_backend" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.mysql_private_nlb.id
  backend_set_name         = oci_network_load_balancer_backend_set.mysql_bs.name
  ip_address               = oci_mysql_mysql_db_system.green.ip_address
  port                     = var.mysql_port
}

resource "oci_network_load_balancer_backend" "mysql_blue_backend" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.mysql_private_nlb.id
  backend_set_name         = oci_network_load_balancer_backend_set.mysql_bs.name
  ip_address               = oci_mysql_mysql_db_system.blue.ip_address
  port                     = var.mysql_port
}

resource "oci_network_load_balancer_listener" "mysql_listener" {
  default_backend_set_name = oci_network_load_balancer_backend_set.mysql_bs.name
  name                     = "mysql-3306"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.mysql_private_nlb.id
  port                     = var.mysql_port
  protocol                 = "TCP"
}
