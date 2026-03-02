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
  - Shared OCI MySQL configuration attached to both Blue/Green DB systems for logical replication readiness
    - `binlog_expire_logs_seconds = 604800`
    - `binlog_row_metadata = FULL`
    - `binlog_transaction_compression = false`
    - `replica_parallel_workers = 4`
- Bastion compute instance in public subnet with:
  - **2 OCPUs**, **16 GB RAM** (flex shape)
  - extra **200 GB block volume** attached
  - cloud-init installs latest available `mysql-shell`
- Private OCI Network Load Balancer with **both Green and Blue MySQL backends** on port **3306**
- OCI GoldenGate MySQL deployment with:
  - **Deployment resource active**
  - **Connection and connection assignment resources temporarily disabled** due to provider/runtime stability issues during apply
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
- `goldengate.tf` - OGG deployment (connections/assignments currently disabled)
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

## Troubleshooting

### Shared MySQL configuration (Blue/Green) parent configuration lookup

If plan/apply fails with:

- `Unable to resolve parent MySQL configuration. Set mysql_configuration_parent_id explicitly for this tenancy/region.`

set `mysql_configuration_parent_id` in your tfvars to an existing **ACTIVE DEFAULT** MySQL configuration OCID for the selected shape/region. By default, this stack auto-discovers that parent configuration from OCI.

### Exact errors observed in manual runs

- `Error: could not infer resource state via reflection`
- `Error acquiring the state lock`
- `Error: Missing required argument` (`resolver_id`)
- `Error in function call ... Call to function "coalesce" failed: no non-null, non-empty-string arguments`

### Destroy (OCI reflection/polling errors)

For long-running OCI deletes (especially GoldenGate/MySQL), Terraform can sometimes fail with:

- `Error: could not infer resource state via reflection`

When this appears during `terraform destroy`, use this deterministic remediation flow:

1. Run normal destroy:

   ```bash
   terraform destroy -auto-approve -no-color
   ```

2. Verify actual lifecycle state in OCI for affected resources (GoldenGate/MySQL).
   - If OCI shows `DELETING`, wait and re-check.
   - If OCI shows `DELETED` but Terraform still tracks the object, continue to step 3.

3. Remove only stale, already-deleted resources from Terraform state:

   ```bash
   terraform state rm <resource-address>
   ```

   Examples used in this stack during recovery:

   ```bash
   terraform state rm oci_golden_gate_connection.mysql_green_connection[0]
   terraform state rm oci_mysql_mysql_db_system.green oci_mysql_mysql_db_system.blue
   ```

4. Re-run destroy:

   ```bash
   terraform destroy -auto-approve -no-color
   ```

5. Validate clean completion:

   ```bash
   terraform state list
   terraform plan -destroy -no-color
   terraform plan -no-color
   ```

Operational rule: treat reflection errors as possible provider polling instability; always verify OCI truth first, then reconcile Terraform state, then retry.

### Apply (manual resume/recovery)

If manual `terraform apply` fails mid-run, use the following recovery patterns.

### 1) DNS resolver_id error

If you see:

- `Error: Missing required argument`
- `with data.oci_dns_resolver.main ... The argument "resolver_id" is required`

This stack now uses a safer resolver/view lookup (`oci_dns_views` for PRIVATE scope), with graceful fallback behavior when no private view is discoverable.

### 2) GoldenGate reflection/polling instability

If you see during GoldenGate connection/assignment create:

- `Error: could not infer resource state via reflection`

Treat this as potential provider polling instability. Verify actual OCI lifecycle state before deciding next action.

> Temporary mode note: this stack currently disables GoldenGate **connection** and **connection assignment** resources in code. If `goldengate_enabled = true`, only the GoldenGate deployment is created.

### 3) Terraform state lock during retry

If you see:

- `Error acquiring the state lock`

it usually means another apply/plan is still running or left a stale lock.

- If a Terraform run is still active: wait for it to complete.
- If no Terraform run is active: release stale lock with:

  ```bash
  terraform force-unlock <LOCK_ID>
  ```

### 4) Tainted GoldenGate connection after interrupted apply

If plan shows a GG connection as tainted and you want to retry without forced replacement first:

```bash
terraform untaint 'oci_golden_gate_connection.mysql_green_connection[0]'
```

Use the Blue equivalent as needed.

> This step is not applicable while GG connections are temporarily disabled.

### 5) Recommended manual recovery command sequence

```bash
terraform validate -no-color
terraform force-unlock <LOCK_ID>   # only if no active Terraform run
terraform plan -no-color
terraform apply -no-color
```

### Sequencing & Idempotency Notes (DNS + GoldenGate)

You are correct that Terraform is declarative and idempotent, and IDs should flow automatically through references. In this stack, the intended dependency chain is:

1. **Network + MySQL**
2. **GoldenGate deployment** (depends on both MySQL DB Systems)
3. **GoldenGate connections** (depend on deployment)
4. **GoldenGate assignments** (depend on deployment + corresponding connection)
5. **Private DNS zone + RRsets** (RRsets depend on zone and target IP-producing resources)

### Hardening implemented for this stack

- DNS resolver lookup replaced with `oci_dns_views` (PRIVATE scope) to avoid brittle `resolver_id` handoff behavior.
- Private DNS resources are now conditionally created only when a usable view ID exists (explicit `private_dns_view_id` or discovered PRIVATE view).
- GoldenGate connections now set `trigger_refresh = false` to reduce provider-induced replacement noise.
- GoldenGate connection/assignment timeouts increased for long OCI control-plane operations.
- Explicit `depends_on` has been added/expanded for assignment sequencing.

### Important caveat

Even with correct dependency wiring, OCI provider polling can still intermittently return reflection/timeouts during long-running GoldenGate operations. That is a provider/runtime behavior (not always a dependency bug), and recovery is done via the runbooks above.

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
- GoldenGate deployment is created only when `goldengate_enabled = true`.
- GoldenGate connection and connection assignment resources are temporarily disabled for stability; related outputs are currently `null`.
