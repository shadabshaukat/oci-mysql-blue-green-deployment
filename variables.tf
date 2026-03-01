variable "region" {
  description = "OCI region (defaulted for this stack)"
  type        = string
  default     = "ap-osaka-1"
}

variable "oci_auth" {
  description = "OCI provider auth mode: ApiKey (local/OCI CLI profile) or ResourcePrincipal (OCI Resource Manager)"
  type        = string
  default     = "ApiKey"
}

variable "oci_config_profile" {
  description = "OCI CLI config profile name"
  type        = string
  default     = "DEFAULT"
}

variable "oci_config_file" {
  description = "Optional path to OCI CLI config file. If null, provider default resolution is used"
  type        = string
  default     = null
}

variable "tenancy_ocid" {
  description = "Tenancy OCID"
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment OCID for all resources"
  type        = string
}

variable "availability_domain" {
  description = "Optional Availability Domain override. If null, first AD in selected region is auto-used"
  type        = string
  default     = null
}

variable "project_prefix" {
  description = "Prefix for resource display names"
  type        = string
  default     = "mysql"
}

variable "vcn_cidr" {
  description = "VCN CIDR"
  type        = string
  default     = "10.30.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR for bastion"
  type        = string
  default     = "10.30.10.0/24"
}

variable "private_subnet_cidr" {
  description = "Single private subnet CIDR for OCI MySQL, GoldenGate, and private NLB"
  type        = string
  default     = "10.30.20.0/24"
}

variable "ssh_public_key" {
  description = "SSH public key for bastion host login"
  type        = string
}

variable "bastion_shape" {
  description = "Compute shape for bastion"
  type        = string
  default     = "VM.Standard.E5.Flex"
}

variable "bastion_os_version" {
  description = "Oracle Linux major version for bastion image selection"
  type        = string
  default     = "8"
}

variable "bastion_ocpus" {
  description = "Bastion OCPU count"
  type        = number
  default     = 2
}

variable "bastion_memory_in_gbs" {
  description = "Bastion memory in GB"
  type        = number
  default     = 16
}

variable "bastion_boot_volume_size_in_gbs" {
  description = "Bastion boot volume size in GB"
  type        = number
  default     = 100
}

variable "bastion_custom_image_ocid" {
  description = "Optional custom image OCID for bastion. If null, latest Oracle Linux image for bastion_os_version is used"
  type        = string
  default     = null
}

variable "bastion_block_volume_size_in_gbs" {
  description = "Extra block volume size in GB"
  type        = number
  default     = 200
}

variable "mysql_admin_username" {
  description = "OCI MySQL admin username"
  type        = string
  default     = "admin"
}

variable "mysql_admin_password" {
  description = "OCI MySQL admin password"
  type        = string
  sensitive   = true
}

variable "mysql_shape_name" {
  description = "OCI MySQL shape"
  type        = string
  default     = "MySQL.2"
}

variable "mysql_version" {
  description = "(Deprecated) Legacy single-DB MySQL version variable. Use mysql_green_version and mysql_blue_version instead"
  type        = string
  default     = "8.4.8"
}

variable "mysql_green_version" {
  description = "OCI MySQL version for Green (staging) environment"
  type        = string
  default     = "8.4.8"
}

variable "mysql_blue_version" {
  description = "OCI MySQL version for Blue (production) environment"
  type        = string
  default     = "8.0.45"
}

variable "mysql_storage_size_in_gb" {
  description = "OCI MySQL data storage in GB"
  type        = number
  default     = 50
}

variable "mysql_hostname_label" {
  description = "(Deprecated) Legacy single-DB MySQL hostname label variable. Use mysql_green_hostname_label and mysql_blue_hostname_label instead"
  type        = string
  default     = "mysql-green"
}

variable "mysql_green_hostname_label" {
  description = "Hostname label for Green (staging) MySQL DB system"
  type        = string
  default     = "mysql-green"
}

variable "mysql_blue_hostname_label" {
  description = "Hostname label for Blue (production) MySQL DB system"
  type        = string
  default     = "mysql-blue"
}

variable "mysql_green_display_name" {
  description = "Display name for Green (staging) MySQL DB system"
  type        = string
  default     = "MySQL-Green"
}

variable "mysql_blue_display_name" {
  description = "Display name for Blue (production) MySQL DB system"
  type        = string
  default     = "MySQL-Blue"
}

variable "mysql_green_environment_tag" {
  description = "Environment tag value for Green resources"
  type        = string
  default     = "green-staging"
}

variable "mysql_blue_environment_tag" {
  description = "Environment tag value for Blue resources"
  type        = string
  default     = "blue-prod"
}

variable "mysql_port" {
  description = "MySQL port"
  type        = number
  default     = 3306
}

variable "mysql_port_x" {
  description = "MySQL X Protocol port"
  type        = number
  default     = 33060
}

variable "mysql_database_name" {
  description = "MySQL database/schema name for GoldenGate MySQL connection"
  type        = string
  default     = "mysql"
}

variable "goldengate_enabled" {
  description = "Create OCI GoldenGate resources"
  type        = bool
  default     = true
}

variable "goldengate_admin_username" {
  description = "GoldenGate deployment admin username"
  type        = string
  default     = "oggadmin"
}

variable "goldengate_admin_password" {
  description = "GoldenGate deployment admin password"
  type        = string
  sensitive   = true
  default     = null
}

variable "goldengate_cpu_core_count" {
  description = "GoldenGate deployment CPU core count"
  type        = number
  default     = 2
}

variable "goldengate_deployment_display_name" {
  description = "Display name for OCI GoldenGate deployment"
  type        = string
  default     = "OCI-Goldengate-MySQL-OGG"
}

variable "goldengate_deployment_name" {
  description = "Deployment name inside GoldenGate ogg_data"
  type        = string
  default     = "mysql-ogg"
}

variable "goldengate_mysql_security_protocol" {
  description = "Security protocol for OCI GoldenGate MySQL connection"
  type        = string
  default     = "PLAIN"
}

variable "goldengate_mysql_technology_type" {
  description = "Technology type for OCI GoldenGate MySQL connection"
  type        = string
  default     = "MYSQL_SERVER"
}

variable "goldengate_connection_assignment_is_lock_override" {
  description = "Whether to override locks when creating GoldenGate connection assignment"
  type        = bool
  default     = false
}

variable "private_dns_zone_name" {
  description = "Private DNS zone name for MySQL service discovery"
  type        = string
  default     = "mysql.local"
}

variable "private_dns_view_id" {
  description = "Optional DNS View OCID for PRIVATE scoped DNS zones. If null, the VCN resolver default view is used dynamically"
  type        = string
  default     = null
}

variable "private_dns_record_ttl" {
  description = "TTL for private DNS A records"
  type        = number
  default     = 30
}

variable "dns_nlb_app_hostname" {
  description = "Hostname prefix for main NLB app endpoint"
  type        = string
  default     = "nlb-app"
}

variable "dns_nlb_blue_hostname" {
  description = "Hostname prefix for blue DB endpoint"
  type        = string
  default     = "nlb-app-blue"
}

variable "dns_nlb_green_hostname" {
  description = "Hostname prefix for green DB endpoint"
  type        = string
  default     = "nlb-app-green"
}
