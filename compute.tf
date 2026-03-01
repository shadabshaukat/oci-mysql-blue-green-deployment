data "oci_core_images" "oracle_linux_latest" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = var.bastion_os_version
  shape                    = var.bastion_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  bastion_cloud_init = <<-EOT
    #cloud-config
    package_update: true
    package_upgrade: true
    runcmd:
      - dnf -y install tmux jq git bind-utils nmap-ncat traceroute tar unzip curl || true
      - dnf -y install mysql-shell || true
      - bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults --install-dir /opt/oci-cli --exec-dir /usr/local/bin || true
      - mkdir -p /data
      - if [ -b /dev/oracleoci/oraclevdb ]; then mkfs -t xfs /dev/oracleoci/oraclevdb; fi
      - if [ -b /dev/oracleoci/oraclevdb ]; then mount /dev/oracleoci/oraclevdb /data; fi
      - if [ -b /dev/oracleoci/oraclevdb ]; then echo '/dev/oracleoci/oraclevdb /data xfs defaults,nofail 0 2' >> /etc/fstab; fi
      - if command -v mysqlsh >/dev/null 2>&1; then mysqlsh --version > /var/log/mysqlsh-version.log; fi
      - if command -v oci >/dev/null 2>&1; then oci --version > /var/log/oci-cli-version.log; fi
  EOT
}

resource "oci_core_instance" "bastion" {
  compartment_id      = var.compartment_ocid
  availability_domain = local.effective_availability_domain
  shape               = var.bastion_shape
  display_name        = "${local.project_prefix}-bastion"

  shape_config {
    ocpus         = var.bastion_ocpus
    memory_in_gbs = var.bastion_memory_in_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_bastion.id
    assign_public_ip = true
    display_name     = "${local.project_prefix}-bastion-vnic"
    hostname_label   = "bastion"
  }

  source_details {
    source_type             = "image"
    source_id               = coalesce(var.bastion_custom_image_ocid, data.oci_core_images.oracle_linux_latest.images[0].id)
    boot_volume_size_in_gbs = var.bastion_boot_volume_size_in_gbs
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(local.bastion_cloud_init)
  }

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    component   = "bastion"
  }
}

resource "oci_core_volume" "bastion_data" {
  compartment_id      = var.compartment_ocid
  availability_domain = local.effective_availability_domain
  display_name        = "${local.project_prefix}-bastion-data"
  size_in_gbs         = var.bastion_block_volume_size_in_gbs

  freeform_tags = {
    environment = var.mysql_green_environment_tag
    component   = "bastion"
  }
}

resource "oci_core_volume_attachment" "bastion_data_attachment" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.bastion.id
  volume_id       = oci_core_volume.bastion_data.id
  device          = "/dev/oracleoci/oraclevdb"
}
