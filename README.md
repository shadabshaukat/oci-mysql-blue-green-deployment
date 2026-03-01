# OCI MySQL Blue/Green Deployment Stack (Terraform)

This Terraform stack provisions a full **blue/green deployment architecture** in OCI for MySQL logical migration workflows.

This version is prepared for **OCI Resource Manager** deployment and local CLI usage, with region defaulted to **ap-osaka-1**.

It creates:

- VCN with **exactly 2 subnets**:
  - one **public subnet** for Bastion
  - one **private subnet** shared by MySQL + GoldenGate + private NLB
- Two OCI MySQL DB Systems (**HA enabled**) in private subnet with same shape/storage:
  - **Green (staging)**: MySQL version **8.4.8 LTS**
  - **Blue (production)**: MySQL version **8.0.45**
  - Shape **MySQL.2**
  - Storage **50 GB**
- Bastion compute instance in public subnet with:
  - **2 OCPUs**, **16 GB RAM** (flex shape)
  - extra **200 GB block volume** attached
  - cloud-init installs latest available `mysql-shell`
- Private OCI Network Load Balancer with **both Green and Blue MySQL backends** on port **3306**
- OCI GoldenGate MySQL deployment with:
  - Green MySQL connection + assignment
  - Blue MySQL connection + assignment
- OCI Private DNS zone/records for application routing:
  - `nlb-app.mysql.local` → NLB private IP
  - `nlb-app-green.mysql.local` → Green MySQL private IP
  - `nlb-app-blue.mysql.local` → Blue MySQL private IP

> Note: provider APIs evolve. If your tenancy/provider version requires slightly different GoldenGate schema fields, adjust attributes accordingly.

## Files

- `versions.tf` - Terraform and provider requirements
- `provider.tf` - OCI provider config
- `variables.tf` - all inputs
- `network.tf` - VCN/subnets/routing/security
- `mysql.tf` - OCI MySQL HA DB Systems (Green and Blue)
- `compute.tf` - bastion VM + block volume + cloud-init
- `nlb.tf` - private NLB + backend set/listener + Green/Blue backends
- `goldengate.tf` - OGG deployment + Green/Blue connections + assignments
- `dns.tf` - private DNS zone + application A records
- `outputs.tf` - key outputs
- `terraform.tfvars.example` - example values
- `deployment.tfvars.template` - reusable variables template for any environment/tenancy
- `TERRAFORM_DEPLOYMENT.md` - detailed step-by-step deployment runbook
- `specifications.md` - full stack specification and continuous change history

## Deploy

## Reusable deployments across environments/tenancies

This repository is designed so each account/tenancy/environment uses its **own tfvars file**.
Examples:
- `env/dev.tfvars` (Dev tenancy/compartment)
- `env/test.tfvars` (Test tenancy/compartment)
- `env/prod.tfvars` (Prod tenancy/compartment)

You can keep completely different values for each file (tenancy OCID, compartment OCID, region, passwords, CIDRs, naming prefix).

Use `deployment.tfvars.template` as the base deployment file:

```bash
cp deployment.tfvars.template env-dev.tfvars
cp deployment.tfvars.template env-prod.tfvars
```

Then set tenancy/compartment/region/passwords per file and run:

```bash
terraform plan -var-file=env-dev.tfvars
terraform apply -var-file=env-dev.tfvars
```

Pre-created environment files are available in:
- `env/dev.tfvars`
- `env/test.tfvars`
- `env/prod.tfvars`

You can use them directly:

```bash
terraform plan  -var-file=env/dev.tfvars
terraform apply -var-file=env/dev.tfvars
```

For OCI Resource Manager, upload stack zip and provide equivalent variable values in stack variables UI.

### Option A: OCI Resource Manager (recommended)

1. Zip this folder content (all `.tf` files plus `schema.yaml`).
2. In OCI Console, go to **Developer Services → Resource Manager → Stacks → Create Stack**.
3. Upload the zip file.
4. In Variables page, provide:
   - `compartment_ocid`
   - `availability_domain` (optional; if omitted, stack auto-selects first AD in selected region)
   - `ssh_public_key`
   - `mysql_admin_password`
   - optionally `goldengate_admin_password`
   - (optional) subnet CIDRs: `public_subnet_cidr`, `private_subnet_cidr`
5. Run **Plan** then **Apply** job.

### OCI Resource Manager note for Availability Domain

If Resource Manager shows "There was an error retrieving options" for Availability Domain, this stack now expects a **plain string** value (not dropdown lookup). Paste the AD name directly (for your tenancy/region) and continue.

This stack also supports **automatic AD discovery**: if `availability_domain` is left empty, Terraform queries availability domains for the selected `region` and uses the first one.

### Option B: Local Terraform CLI

1. Copy example variables:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Update values in `terraform.tfvars`.

3. Run:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

> For local CLI usage, ensure your OCI API key profile (typically `DEFAULT`) is configured in your OCI config.

## Blue-Green Logical Migration: What Else You Should Add

To make this a production-ready blue-green deployment using logical replication:

1. **Provision a second MySQL HA system (blue)**
   - Add another `oci_mysql_mysql_db_system` resource (`blue`) in private subnet.
   - Keep shape/version parity with green for predictable cutover.

2. **GoldenGate end-to-end pipeline (not just connection objects)**
   - Source connection (current prod / blue)
   - Target connection (green)
   - Replication assignment (Extract/Pump/Replicat equivalent) with mapping rules
   - Checkpointing and error handling policy

3. **Cutover strategy via private NLB backend switch**
   - Use NLB backend target move from blue IP to green IP during cutover.
   - Keep rollback path documented (switch backend back to blue).

4. **Data consistency validation before cutover**
   - Row count/checksum validation jobs
   - Replication lag SLO threshold gate

5. **Observability and alarms**
   - OCI Monitoring alarms for MySQL CPU, storage, connection count, and OGG health.
   - Notifications for replication lag and process failures.

6. **Secrets management**
   - Move DB and OGG passwords from tfvars to OCI Vault secrets.

7. **Backup + DR posture**
   - Enable and validate automatic backups, retention, and restore runbook.

8. **Network hardening**
   - Prefer NSGs over broad security lists for fine-grained flows.
   - Restrict bastion SSH source CIDRs to your office/VPN IPs.

9. **Change orchestration**
   - Separate modules/workspaces for blue and green environments.
   - CI/CD pipeline with approval gates for cutover and rollback.

## Important Notes

- This stack has been updated and validated against OCI Terraform provider schema for **oracle/oci v8.3.0** (including `oci_mysql_mysql_db_system`, `oci_core_instance`, `oci_network_load_balancer_*`, and `oci_golden_gate_*` resources).
- OCI MySQL shape `MySQL.2` corresponds to the requested sizing profile.
- `mysql-shell` package installation in cloud-init uses Oracle Linux repositories and installs the latest available version at provisioning time.
- GoldenGate deployment/connection are created only when `goldengate_enabled = true`.
