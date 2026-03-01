output "vcn_id" {
  description = "VCN OCID"
  value       = oci_core_vcn.main.id
}

output "public_bastion_subnet_id" {
  description = "Public subnet OCID for bastion"
  value       = oci_core_subnet.public_bastion.id
}

output "private_subnet_id" {
  description = "Private subnet OCID shared by MySQL, GoldenGate, and private NLB"
  value       = oci_core_subnet.private.id
}

output "mysql_db_system_id" {
  description = "OCI MySQL Green DB System OCID"
  value       = oci_mysql_mysql_db_system.green.id
}

output "mysql_db_system_ip" {
  description = "OCI MySQL Green private IP"
  value       = oci_mysql_mysql_db_system.green.ip_address
}

output "mysql_db_system_endpoint" {
  description = "OCI MySQL Green endpoint"
  value = (
    oci_mysql_mysql_db_system.green.ip_address != null
    ? "${oci_mysql_mysql_db_system.green.ip_address}:${var.mysql_port}"
    : null
  )
}

output "mysql_blue_db_system_id" {
  description = "OCI MySQL Blue DB System OCID"
  value       = oci_mysql_mysql_db_system.blue.id
}

output "mysql_blue_db_system_ip" {
  description = "OCI MySQL Blue private IP"
  value       = oci_mysql_mysql_db_system.blue.ip_address
}

output "mysql_blue_db_system_endpoint" {
  description = "OCI MySQL Blue endpoint"
  value = (
    oci_mysql_mysql_db_system.blue.ip_address != null
    ? "${oci_mysql_mysql_db_system.blue.ip_address}:${var.mysql_port}"
    : null
  )
}

output "bastion_instance_id" {
  description = "Bastion instance OCID"
  value       = oci_core_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Bastion public IP"
  value       = oci_core_instance.bastion.public_ip
}

output "nlb_private_ip" {
  description = "Private NLB IP"
  value       = oci_network_load_balancer_network_load_balancer.mysql_private_nlb.ip_addresses[0].ip_address
}

output "goldengate_deployment_id" {
  description = "GoldenGate deployment OCID"
  value       = var.goldengate_enabled ? oci_golden_gate_deployment.mysql_deployment[0].id : null
}

output "goldengate_mysql_connection_id" {
  description = "GoldenGate MySQL Green connection OCID"
  value       = var.goldengate_enabled ? oci_golden_gate_connection.mysql_green_connection[0].id : null
}

output "goldengate_mysql_blue_connection_id" {
  description = "GoldenGate MySQL Blue connection OCID"
  value       = var.goldengate_enabled ? oci_golden_gate_connection.mysql_blue_connection[0].id : null
}

output "goldengate_connection_assignment_id" {
  description = "GoldenGate MySQL Green connection assignment OCID"
  value       = var.goldengate_enabled ? oci_golden_gate_connection_assignment.mysql_connection_assignment[0].id : null
}

output "goldengate_blue_connection_assignment_id" {
  description = "GoldenGate MySQL Blue connection assignment OCID"
  value       = var.goldengate_enabled ? oci_golden_gate_connection_assignment.mysql_blue_connection_assignment[0].id : null
}

output "private_dns_zone_id" {
  description = "Private DNS zone OCID"
  value       = oci_dns_zone.private_mysql_zone.id
}

output "dns_nlb_app_fqdn" {
  description = "Main application FQDN resolving to MySQL private NLB IP"
  value       = "${var.dns_nlb_app_hostname}.${trimsuffix(var.private_dns_zone_name, ".")}"
}

output "dns_nlb_blue_fqdn" {
  description = "Blue MySQL direct FQDN"
  value       = "${var.dns_nlb_blue_hostname}.${trimsuffix(var.private_dns_zone_name, ".")}"
}

output "dns_nlb_green_fqdn" {
  description = "Green MySQL direct FQDN"
  value       = "${var.dns_nlb_green_hostname}.${trimsuffix(var.private_dns_zone_name, ".")}"
}
