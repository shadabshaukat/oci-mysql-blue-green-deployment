oci_auth           = "ApiKey"
oci_config_profile = "DEFAULT"
region             = "ap-osaka-1"

tenancy_ocid     = "ocid1.tenancy.oc1..replace_me"
compartment_ocid = "ocid1.compartment.oc1..replace_me"

availability_domain = null

project_prefix = "mysql-test"

vcn_cidr            = "10.40.0.0/16"
public_subnet_cidr  = "10.40.10.0/24"
private_subnet_cidr = "10.40.20.0/24"

ssh_public_key = "ssh-ed25519 REPLACE_WITH_YOUR_KEY"

mysql_admin_password      = "REPLACE_WITH_STRONG_PASSWORD"
goldengate_admin_password = "REPLACE_WITH_STRONG_PASSWORD"

mysql_shape_name            = "MySQL.2"
mysql_storage_size_in_gb    = 50
mysql_green_version         = "8.4.8"
mysql_blue_version          = "8.0.45"
mysql_green_display_name    = "MySQL-Green"
mysql_blue_display_name     = "MySQL-Blue"
mysql_green_hostname_label  = "mysql-green"
mysql_blue_hostname_label   = "mysql-blue"
mysql_green_environment_tag = "green-staging"
mysql_blue_environment_tag  = "blue-prod"
mysql_shared_configuration_enabled          = true
mysql_shared_configuration_display_name     = "MySQL-BlueGreen-Shared-Config"
mysql_shared_configuration_description      = "Shared MySQL configuration for Blue/Green logical replication and GoldenGate readiness"
mysql_configuration_parent_id               = null
mysql_config_binlog_expire_logs_seconds     = 604800
mysql_config_binlog_row_metadata            = "FULL"
mysql_config_binlog_transaction_compression = false
mysql_config_replica_parallel_workers       = 4

bastion_shape                    = "VM.Standard.E5.Flex"
bastion_os_version               = "8"
bastion_ocpus                    = 2
bastion_memory_in_gbs            = 16
bastion_block_volume_size_in_gbs = 200

goldengate_enabled                                = true
goldengate_admin_username                         = "oggadmin"
goldengate_cpu_core_count                         = 2
goldengate_deployment_display_name                = "OCI-Goldengate-MySQL-OGG"
goldengate_deployment_name                        = "mysql-ogg"
goldengate_connection_assignment_is_lock_override = false
goldengate_mysql_technology_type                  = "MYSQL_SERVER"
goldengate_mysql_security_protocol                = "PLAIN"
mysql_database_name                               = "mysql"

private_dns_zone_name  = "mysql.local"
private_dns_record_ttl = 30
dns_nlb_app_hostname   = "nlb-app"
dns_nlb_blue_hostname  = "nlb-app-blue"
dns_nlb_green_hostname = "nlb-app-green"
