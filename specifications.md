# OCI MySQL Blue-Green Stack Specifications

## 1) Initial Build Specification

### Objective
Provision a reusable OCI Terraform stack for MySQL blue-green foundation using logical migration methodology.

### Core Architecture
- VCN with **2 subnets only**:
  1. **Public subnet**: Bastion compute
  2. **Private subnet**: OCI MySQL HA + OCI GoldenGate + Private NLB

### Provisioned Components
1. **OCI MySQL DB System (Green)**
   - Engine version: `8.0.45`
   - Shape: `MySQL.2`
   - Storage: `50 GB`
   - Hostname label: `mysql-green`
   - Highly available: `true`
   - Private subnet placement

2. **Bastion Compute**
   - Shape: `VM.Standard.E5.Flex`
   - OCPU: `2`
   - Memory: `16 GB`
   - Additional block volume: `200 GB`
   - Public subnet placement
   - Cloud-init installs latest available `mysql-shell`

3. **Private NLB**
   - Private NLB in private subnet
   - Listener: TCP `3306`
   - Backend set policy: `FIVE_TUPLE`
   - Backend target: OCI MySQL private IP and port `3306`

4. **OCI GoldenGate**
   - Deployment type: `MYSQL`
   - **Temporary stability mode:** only deployment is active
   - GoldenGate connection and connection-assignment resources are currently disabled in code

5. **Placement/AD behavior**
   - Region variable default: `ap-osaka-1`
   - Availability Domain is optional input
   - If unset, stack auto-discovers ADs in selected region and uses first AD

6. **Shared MySQL configuration for Blue/Green replication readiness**
   - Both DB systems can attach a common OCI MySQL configuration (`oci_mysql_mysql_configuration`)
   - Parent configuration is auto-discovered from OCI (`ACTIVE` + `DEFAULT` for selected shape) unless explicitly provided
   - Replication-focused defaults:
     - `binlog_expire_logs_seconds = 604800`
     - `binlog_row_metadata = FULL`
     - `binlog_transaction_compression = false`
     - `replica_parallel_workers = 4`

### Authentication Behavior
- Local/CLI default mode: `ApiKey` with OCI CLI profile (`DEFAULT`)
- Supports Resource Manager mode by setting `oci_auth = "ResourcePrincipal"`

---

## 2) Reusable Deployment Model

This repository includes:
- `deployment.tfvars.template` for cloning per environment/tenancy
- `terraform.tfvars` for current configured environment

Recommended pattern:
- `env-dev.tfvars`
- `env-test.tfvars`
- `env-prod.tfvars`

Repository also includes ready-to-use structure:
- `env/dev.tfvars`
- `env/test.tfvars`
- `env/prod.tfvars`

### Multi-tenancy usage rule
Use a **different tfvars file per tenancy/account/environment**. Do not share one tfvars file across all environments.

Examples:
```bash
terraform plan -var-file=env/dev.tfvars
terraform plan -var-file=env/test.tfvars
terraform plan -var-file=env/prod.tfvars
```

Run example:
```bash
terraform plan -var-file=env-dev.tfvars
terraform apply -var-file=env-dev.tfvars
```

---

## 3) Continuous Change History

> Maintain this section for every enhancement/fix.

### 2026-02-28 — Initial complete stack
- Added provider, versions, variables, networking, MySQL, compute, NLB, GoldenGate, outputs.

### 2026-02-28 — Resource Manager compatibility updates
- Added `schema.yaml` for OCI Resource Manager stack UI.
- Added deployment documentation and packaging flow.

### 2026-02-28 — Two subnet architecture refactor
- Removed separate private NLB/GG subnets.
- Enforced one public + one private subnet model.
- Updated dependent resources and outputs.

### 2026-02-28 — Provider compatibility hardening (oracle/oci v8.3.0)
- Fixed NLB argument name to `is_preserve_source_destination`.
- Updated GoldenGate deployment/connection schema usage.

### 2026-02-28 — AD selection behavior improvements
- Made `availability_domain` optional.
- Implemented AD auto-discovery from selected `region`.

### 2026-02-28 — Local OCI CLI profile planning support
- Removed hard Resource Principal dependency.
- Added provider auth/profile variables and validated plan with provided tenancy values.

### 2026-02-28 — GoldenGate connection recovery/resume (continuity log)
- Context: Terraform apply was failing during `oci_golden_gate_connection` create in OCI GoldenGate.
- Checked latest resource guidance from provider docs (`oci_golden_gate_connection`) using upstream provider markdown source due Terraform Registry JS page rendering in CLI.
- Updated `goldengate.tf` connection resource for MySQL target:
  - `connection_type = "MYSQL"`
  - `technology_type = var.goldengate_mysql_technology_type` (effective value validated as `MYSQL_SERVER`)
  - added `database_name = var.mysql_database_name`
  - added `security_protocol = var.goldengate_mysql_security_protocol` (effective value `PLAIN`)
- Added new variables in `variables.tf`:
  - `mysql_database_name` (default `mysql`)
  - `goldengate_mysql_security_protocol` (default `PLAIN`)
  - `goldengate_mysql_technology_type` (default `MYSQL_SERVER`)

#### Error continuity trail captured during recovery
1. `400-InvalidParameter, Invalid TechnologyType: DATABASE_MYSQL`
2. `400-InvalidParameter, Invalid SecurityProtocol:`
3. `400-InvalidParameter, Invalid TechnologyType: MYSQL`
4. `Error: could not infer resource state via reflection` (during create polling)

#### State continuity and current status
- `terraform state list` confirms resource now present:
  - `oci_golden_gate_connection.mysql_green_connection[0]`
- A taint occurred during failed create/poll cycle and was cleared:
  - `terraform untaint 'oci_golden_gate_connection.mysql_green_connection[0]'`
- Latest `terraform plan` shows **no infra changes**, only output-state sync:
  - `goldengate_mysql_connection_id = ocid1.goldengateconnection...`

#### Resume-later quick commands
```bash
terraform plan -no-color
terraform apply -no-color
terraform output goldengate_mysql_connection_id
```

### 2026-02-28 — GoldenGate connection assignment automation
- Implemented dynamic assignment of the created MySQL GoldenGate connection to the created GoldenGate deployment using Terraform resource:
  - `oci_golden_gate_connection_assignment.mysql_connection_assignment`
- Wiring is fully dynamic and environment-agnostic:
  - `connection_id = oci_golden_gate_connection.mysql_green_connection[0].id`
  - `deployment_id = oci_golden_gate_deployment.mysql_deployment[0].id`
  - guarded by `count = var.goldengate_enabled ? 1 : 0`
- Added variable:
  - `goldengate_connection_assignment_is_lock_override` (default `false`)
- Added/propagated GoldenGate connection compatibility defaults for continuity across environments:
  - `goldengate_mysql_technology_type = "MYSQL_SERVER"`
  - `goldengate_mysql_security_protocol = "PLAIN"`
  - `mysql_database_name = "mysql"`
- Updated variable examples/templates and env tfvars files:
  - `terraform.tfvars`
  - `deployment.tfvars.template`
  - `terraform.tfvars.example`
  - `env/dev.tfvars`, `env/test.tfvars`, `env/prod.tfvars`
- Apply resume status:
  - `oci_golden_gate_connection_assignment.mysql_connection_assignment[0]` created successfully.
  - Creation time observed: ~`1m26s` (with normal “Still creating...” progression, no final error).
- Added output for future continuity:
  - `goldengate_connection_assignment_id`

### 2026-03-01 — Full stack destroy and continuity checkpoint
- User-requested full teardown executed to prepare for upcoming blue-environment and additional feature work.

#### Destroy run #1 outcome (partial + provider reflection error)
- Command used:
  - `terraform destroy -auto-approve -no-color`
- Observed long-running GoldenGate deployment deletion:
  - `oci_golden_gate_deployment.mysql_deployment[0]: Still destroying...`
  - Completed after ~`8m13s`
- Immediately after that, Terraform returned:
  - `Error: could not infer resource state via reflection`
- Result: destroy did **not** complete cleanly in this first run; residual resources remained in state.

#### Validation after failed first run
- `terraform state list` still showed managed resources (network + MySQL + GoldenGate connection).
- `terraform plan -destroy -no-color` showed pending destroys (`Plan: 0 to add, 0 to change, 7 to destroy`).

#### Destroy run #2 outcome (successful)
- Re-ran:
  - `terraform destroy -auto-approve -no-color`
- Long-running resource in this pass:
  - `oci_mysql_mysql_db_system.green` (destroy completed after ~`3m51s`)
- Final terminal result:
  - `Destroy complete! Resources: 7 destroyed.`

#### Post-destroy verification
- `terraform state list` returns no managed resources.
- `terraform plan -destroy -no-color` returns:
  - `No changes. No objects need to be destroyed.`

#### Resume-later checkpoint commands
```bash
terraform state list
terraform plan -destroy -no-color
terraform plan -no-color
```

### 2026-03-01 — Blue/Green dual-environment implementation (dynamic)
- Refactored stack to provision both MySQL environments in the same deployment:
  - **Green/Staging** MySQL = `8.4.8` (LTS)
  - **Blue/Production** MySQL = `8.0.45`
- Implemented explicit naming/tagging model aligned with request:
  - Green tag: `green-staging`
  - Blue tag: `blue-prod`
  - GoldenGate deployment display name: `OCI-Goldengate-MySQL-OGG`
  - MySQL display names: `MySQL-Green`, `MySQL-Blue`
- Removed `mysql-green-blue` naming from runtime resource defaults and replaced with neutral/dynamic `project_prefix = "mysql"` (environment files use `mysql-dev`, `mysql-test`, `mysql-prod`).

#### Terraform resources added/updated
1. **MySQL layer (`mysql.tf`)**
   - Added second DB system resource: `oci_mysql_mysql_db_system.blue`
   - Existing `green` resource updated to new version/name/tag model.

2. **GoldenGate layer (`goldengate.tf`)**
   - Deployment now depends on both DB systems.
   - Added Blue connection:
     - `oci_golden_gate_connection.mysql_blue_connection`
   - Added Blue assignment:
     - `oci_golden_gate_connection_assignment.mysql_blue_connection_assignment`
   - Green connection/assignment retained and normalized to requested naming model.

3. **NLB layer (`nlb.tf`)**
   - Single private NLB retained.
   - Backend set retained.
   - Added dual backends:
     - `oci_network_load_balancer_backend.mysql_green_backend`
     - `oci_network_load_balancer_backend.mysql_blue_backend`

4. **Private DNS layer (`dns.tf`)**
   - Added private DNS zone:
     - `oci_dns_zone.private_mysql_zone` (`mysql.local` by default)
   - Added A records:
     - `nlb-app.mysql.local` → NLB private IP
     - `nlb-app-blue.mysql.local` → Blue MySQL private IP
     - `nlb-app-green.mysql.local` → Green MySQL private IP

5. **Outputs (`outputs.tf`)**
   - Added Blue DB outputs (ID/IP/endpoint).
   - Added Blue GoldenGate connection and assignment outputs.
   - Added DNS outputs (zone id + fqdn outputs for app/blue/green endpoints).

#### Variables and config propagation
- Extended `variables.tf` with dual-environment controls:
  - `mysql_green_version`, `mysql_blue_version`
  - `mysql_green_display_name`, `mysql_blue_display_name`
  - `mysql_green_hostname_label`, `mysql_blue_hostname_label`
  - `mysql_green_environment_tag`, `mysql_blue_environment_tag`
  - `goldengate_deployment_display_name`, `goldengate_deployment_name`
  - DNS controls (`private_dns_zone_name`, `private_dns_record_ttl`, and three hostnames)
- Propagated defaults to:
  - `terraform.tfvars`
  - `deployment.tfvars.template`
  - `terraform.tfvars.example`
  - `env/dev.tfvars`, `env/test.tfvars`, `env/prod.tfvars`

#### Validation checkpoint
- `terraform fmt -recursive` completed.
- `terraform validate` returned success.
- `terraform plan -no-color` result after refactor:
  - `Plan: 29 to add, 0 to change, 0 to destroy`
  - Includes dual MySQL, dual GoldenGate connections/assignments, dual NLB backends, private DNS zone + records.

### 2026-03-01 — Promotion automation strategy (minimum app impact)

#### Desired runtime behavior
- Applications use `nlb-app.mysql.local` as the stable endpoint.
- Only one DB backend should be active for write traffic at a time.
- Promotion should minimize connection drops, transaction errors, and stale reads.

#### Strategy A (recommended): NLB drain + weighted cutover orchestration
1. Keep Blue as active write target and Green in validation mode.
2. During promotion, orchestrator updates NLB backend flags in sequence:
   - mark current active backend to `is_drain=true`
   - keep new target backend online (`is_offline=false`)
   - wait for connection drain grace window (e.g., 30–120s)
3. Flip old backend to `is_offline=true` when connection count reaches low threshold.
4. Keep rollback quick path by re-enabling old backend if post-cutover checks fail.

Implementation options:
- OCI Functions + OCI Events + OCI DevOps pipeline
- GitHub Actions / Jenkins pipeline calling OCI CLI/SDK
- Terraform-driven toggle via dedicated variables in a promotion stage (separate from infra provisioning)

#### Strategy B: DNS-assisted cutover
- Keep `nlb-app.mysql.local` as app endpoint and reduce TTL (already configurable, default `30`).
- For staged migrations, update A record target to alternate endpoint if required.
- Best used as secondary control; NLB backend drain should remain primary to avoid abrupt client reconnect storms.

#### Strategy C: Progressive traffic shifting
- If app/proxy layer supports canary sessions, route a percentage to Green for soak tests.
- Run synthetic transactions + business KPI checks before full promotion.
- Promote only when lag, error rate, and query latency SLOs are satisfied.

### 2026-03-01 — Initial load and CDC options (Blue -> Green)

#### Option 1: OCI GoldenGate (preferred for heterogeneous and controlled CDC)
- Use GoldenGate to establish:
  - initial load into Green
  - continuous CDC from Blue to Green
- Validate checkpoints:
  - replication lag within threshold
  - DDL/DML compatibility checks
  - row-count/checksum validation for critical tables
- Promotion gate: Green must be caught up to near-zero lag before write cutover.

#### Option 2: MySQL channel replication (native MySQL)
- Configure asynchronous replication channel from Blue to Green.
- Use GTID-based replication with monitored lag and failover runbook.
- Pros: native MySQL mechanism, lower moving parts.
- Cons: less flexible than GoldenGate for transformation/filtering or broader integration patterns.

#### Recommended enterprise pattern
- Primary: GoldenGate CDC + controlled initial load workflow.
- Optional fallback: MySQL channel replication for simpler estates.
- Always couple with promotion pipeline gates:
  - data consistency pass
  - lag threshold pass
  - application smoke + read/write verification
  - rollback criteria pre-defined.

### 2026-03-01 — Bastion OS/package baseline hardening
- Added bastion OS version parameterization:
  - `bastion_os_version` for selecting latest Oracle Linux image by major version.
- Added operational packages in cloud-init for DB/network/DNS troubleshooting:
  - `mysql-shell`, `tmux`, `jq`, `git`, `bind-utils`, `nmap-ncat`, `traceroute`, `tar`, `unzip`
- Rationale:
  - `tmux` for resilient long-running sessions
  - `bind-utils`/`nmap-ncat` for DNS + TCP endpoint verification (`nlb-app`, DB backends)
  - `jq` and `git` for automation and diagnostics
- OCI version guidance:
  - Oracle Linux `10` can be used when image availability is confirmed for region/shape.
  - Current stack default is `8` (rolled back from `9` after package availability regression); users can set `bastion_os_version = "10"` or provide `bastion_custom_image_ocid` if needed.

### 2026-03-01 — OCI CLI install in bastion cloud-init
- Added OCI CLI installation in bastion cloud-init using Oracle's official installer script to ensure latest OCI CLI at provision time.
- Cloud-init now records CLI version into:
  - `/var/log/oci-cli-version.log`
- Added `curl` package prerequisite to support installer download.

### 2026-03-01 — Dynamic PRIVATE DNS view + bastion mysql-shell root-cause/fix

#### Dynamic PRIVATE DNS view resolution (tenancy/region portable)
- Removed hard dependency on a tenancy-specific DNS View OCID and implemented dynamic fallback logic.
- `dns.tf` now resolves effective view id as:
  - `coalesce(var.private_dns_view_id, data.oci_dns_resolver.main.default_view_id)`
- Added data sources:
  - `data "oci_core_vcn_dns_resolver_association" "main"` (from VCN id)
  - `data "oci_dns_resolver" "main"` (from resolver id)
- `oci_dns_zone.private_mysql_zone.view_id` now uses `local.effective_private_dns_view_id`.
- Result: stack remains portable across tenancies/regions while still allowing explicit override via `private_dns_view_id` when desired.

#### mysql-shell install regression — verified root cause
- Bastion SSH diagnostics performed using provided key:
  - `ssh -i /Users/shadab/Download ... opc@217.142.252.71`
- Evidence from bastion logs:
  - `/var/log/cloud-init-output.log` contains:
    - `No match for argument: mysql-shell`
    - `Error: Unable to find a match: mysql-shell`
- Runtime package check confirms package missing in enabled OL9 repos:
  - `dnf info mysql-shell` → `Error: No matching Packages to list`
  - Enabled repos were Oracle Linux base/appstream/addons/oci-included only.
- Conclusion: regression was repo availability (mysql-shell not present in default OL9 enabled repos), not Terraform interpolation failure.

#### Bastion cloud-init hardening implemented (superseded)
- A temporary OL9-specific mysql-shell fallback using MySQL EL9 community repo was implemented during investigation.
- This was later superseded by the explicit user-requested rollback to Oracle Linux 8 baseline.

#### Current Terraform continuity status
- `terraform validate -no-color` passes.
- `terraform plan -no-color` currently shows GoldenGate resources pending create and two GoldenGate connections marked tainted/replacement.
- Resume options:
```bash
terraform untaint 'oci_golden_gate_connection.mysql_green_connection[0]'
terraform untaint 'oci_golden_gate_connection.mysql_blue_connection[0]'
terraform plan -no-color
terraform apply -no-color
```

### 2026-03-01 — User-requested rollback to Oracle Linux 8 for bastion

- Based on runtime regression concerns with Oracle Linux 9 package availability, bastion defaults were rolled back to Oracle Linux 8 behavior.

#### What was reverted
- Bastion OS default changed from `9` to `8` in:
  - `variables.tf`
  - `terraform.tfvars`
  - `deployment.tfvars.template`
  - `terraform.tfvars.example`
  - `env/dev.tfvars`
  - `env/test.tfvars`
  - `env/prod.tfvars`
  - `schema.yaml`

#### Cloud-init package flow rollback
- Reverted bastion mysql-shell install logic in `compute.tf` back to the simpler pre-OL9 workaround style:
  - `dnf -y install mysql-shell || true`
  - version capture remains:
    - `if command -v mysqlsh ...; then mysqlsh --version > /var/log/mysqlsh-version.log; fi`
- Removed EL9-specific repo bootstrap reference from runtime config:
  - `mysql84-community-release-el9-1.noarch.rpm`

#### Operational intent
- This keeps bastion behavior aligned with the previously working OL8 baseline while preserving other stack improvements (including dynamic DNS view resolution without hardcoded OCIDs).
- Recommended re-apply scope for minimal change blast radius:
```bash
terraform apply -target=oci_core_instance.bastion -target=oci_core_volume_attachment.bastion_data_attachment -auto-approve -no-color
```

### 2026-03-01 — GoldenGate duplicate deployment closure + portability audit

#### GoldenGate duplicate root cause and resolution
- Performed full Terraform + OCI verification after user observed two deployments with the same display name.
- Confirmed Terraform code logic creates exactly one deployment (`count = var.goldengate_enabled ? 1 : 0`) and two connection assignments (Green + Blue) to that single deployment.
- Confirmed issue was **state/inventory drift**, not duplicate Terraform resource logic:
  - intended deployment was imported into Terraform state,
  - orphan duplicate deployment was deleted in OCI and reached `DELETED`.

#### Final GoldenGate status verification
- `terraform apply -auto-approve -no-color` completed successfully:
  - `Apply complete! Resources: 2 added, 1 changed, 0 destroyed.`
- Both assignment resources completed and are active:
  - `oci_golden_gate_connection_assignment.mysql_connection_assignment[0]`
  - `oci_golden_gate_connection_assignment.mysql_blue_connection_assignment[0]`
- `terraform plan -no-color` post-apply result:
  - `No changes. Your infrastructure matches the configuration.`
- OCI verification (`ap-osaka-1`) confirms:
  - one intended deployment in `ACTIVE` state,
  - prior duplicate in `DELETED` state,
  - both Green and Blue connection assignments in `ACTIVE` state and attached to the intended deployment.

#### Portability and hardcoding audit notes
- Scanned Terraform source for hardcoded OCIDs; none found in `.tf` infrastructure code.
- Updated variable defaults to avoid machine-specific paths:
  - `variables.tf`: `oci_config_file` default changed from `/Users/shadab/.oci/config` to `null`.
- Result: stack remains portable across users/workstations and tenancies while still allowing explicit OCI config path override when needed.

### 2026-03-01 — Full destroy/apply E2E validation attempt (continuity checkpoint)

#### Objective in this run
- User requirement remained to validate full lifecycle end-to-end:
  - full `terraform destroy`
  - full `terraform apply`
  - 60-second cadence monitoring

#### Destroy/apply chain outcome in this checkpoint
- A prior destroy had already shown provider instability around GoldenGate with:
  - `Error: could not infer resource state via reflection`
- Apply run from wrapper log (`/tmp/terraform-apply-1772291573.log`) progressed through major infra creation:
  - VCN/subnets/routes/security
  - bastion + volume attachment
  - private DNS zone + records
  - private NLB + listener + blue/green backends
- GoldenGate resources remained the long-running point:
  - `oci_golden_gate_deployment.mysql_deployment[0]: Still creating...`
- Terminal failure markers captured:
  - `Interrupt received. Gracefully shutting down...`
  - `Error: execution halted`
  - `Error: Plugin did not respond`
  - `Error: could not infer resource state via reflection` (both GG connections)

#### State and plan continuity after failed apply
- `terraform state list` shows substantial resources still managed (network, MySQL, NLB, DNS, bastion, GG connections).
- `terraform plan -destroy -no-color` summary indicates teardown still pending:
  - `Plan: 0 to add, 0 to change, 26 to destroy`
- `terraform plan -no-color` indicates GG drift/reconciliation pending:
  - `Plan: 5 to add, 0 to change, 2 to destroy`
  - includes re-create of GoldenGate deployment + assignments.

#### OCI GoldenGate continuity snapshot
- Deployment list (`ap-osaka-1`) for `OCI-Goldengate-MySQL-OGG` shows:
  - one deployment in `CREATING`
  - prior historical ones in `DELETED`
- Connection assignment list returned empty in this snapshot.

#### Resume-later commands
```bash
terraform state list
terraform plan -destroy -no-color
terraform destroy -auto-approve -no-color
terraform apply -auto-approve -no-color
terraform plan -no-color
```

### 2026-03-01 — GoldenGate assignment conflict/timeouts resolved to clean state

#### Continuity issue observed
- Repeated apply attempts after deployment/connection recovery failed while creating assignments, with alternating provider/API symptoms:
  - `could not infer resource state via reflection`
  - `read: operation timed out` on `POST /connectionAssignments`
  - later `409-Conflict ... Connection ... is already assigned to Deployment ...`
- This indicated assignment resources were intermittently being created in OCI but not consistently converged in Terraform state due timeout/reflection failures.

#### Root cause in this phase
- **State drift + provider behavior under long GG assignment create polling**:
  - Green assignment existed in OCI but not in Terraform state at some checkpoints.
  - Blue assignment was pending create.
  - Imported Green assignment showed `is_lock_override` drift forcing replacement of an already-active assignment.

#### Actions taken
1. Verified current GG resources in state and OCI (deployment + both connections active).
2. Enumerated GG connection assignments via OCI raw API by `compartmentId` (since other list paths/filters returned 404 in this environment).
3. Imported existing Green assignment into Terraform state:
   - `oci_golden_gate_connection_assignment.mysql_connection_assignment[0]`
   - `ocid1.goldengateconnectionassignment...4z3g...`
4. Updated `goldengate.tf` to remove explicit `is_lock_override` from both assignment resources, preventing forced replacement drift on imported active assignment.
5. Re-ran apply for remaining drift only (Blue assignment):
   - `Apply complete! Resources: 1 added, 0 changed, 0 destroyed.`
   - Blue assignment created:
     - `ocid1.goldengateconnectionassignment...5mbt...`

#### Final verified status
- Terraform post-fix plan is clean:
  - `No changes. Your infrastructure matches the configuration.`
- Active assignment IDs now managed:
  - Green assignment: `ocid1.goldengateconnectionassignment.oc1.ap-osaka-1.amaaaaaawiclygaa4z3gdenehtlr4uulj2bm2tzm5vf3sm3ivkd47i3m5xiq`
  - Blue assignment: `ocid1.goldengateconnectionassignment.oc1.ap-osaka-1.amaaaaaawiclygaa5mbtq3xeiitx2mvnj36ggnao3k7tqkqcxu7f4kua577a`

#### Operational checkpoint commands
```bash
terraform state list | grep oci_golden_gate
terraform plan -no-color
terraform output goldengate_connection_assignment_id
terraform output goldengate_blue_connection_assignment_id
```

### 2026-03-01 — Destroy resiliency checkpoint (provider reflection + long MySQL delete)

#### Context
- Manual `terraform destroy` hit intermittent OCI provider behavior during teardown:
  - `Error: could not infer resource state via reflection`
- This occurred after GoldenGate resources had already transitioned in OCI, leaving temporary state drift.

#### What happened in this run
1. Initial destroy pass failed around GoldenGate connection/deployment polling.
2. Verified actual OCI lifecycle directly:
   - GoldenGate connection(s): already `DELETED` in OCI
   - GoldenGate deployment: moved through `DELETING` then `DELETED`
3. Removed stale already-deleted objects from Terraform state to unblock deterministic retry:
   - `terraform state rm oci_golden_gate_connection.mysql_green_connection[0]`
   - later removed stale MySQL resources once OCI confirmed both DB Systems were `DELETED`:
     - `terraform state rm oci_mysql_mysql_db_system.green oci_mysql_mysql_db_system.blue`
4. Re-ran `terraform destroy -auto-approve -no-color`.
5. Final destroy completed cleanly:
   - `Destroy complete! Resources: 6 destroyed.`

#### Key operational guidance for manual/portable workflow
- For OCI long-running deletes (GoldenGate/MySQL), treat `reflection` errors as potential provider polling instability, not always failed API delete.
- Before retrying, verify real OCI lifecycle state (`DELETING`/`DELETED`) via OCI CLI.
- If resource is confirmed `DELETED` in OCI but still in TF state, remove with `terraform state rm` and continue destroy.

#### Resume-later verification commands
```bash
terraform state list
terraform plan -destroy -no-color
terraform plan -no-color
```

### 2026-03-01 — Apply recovery checkpoint (DNS resolver_id + lock + GoldenGate taint)

#### What failed during manual apply
- DNS data source chain failed with:
  - `Error: Missing required argument`
  - `with data.oci_dns_resolver.main ... The argument "resolver_id" is required`
- GoldenGate create path also surfaced intermittent provider polling behavior:
  - `Error: could not infer resource state via reflection`
- A Terraform state lock was observed from a concurrent/previous run:
  - `Error acquiring the state lock ... OperationTypeApply`

#### Root cause and code fix
- The previous DNS resolver lookup used a two-step chain:
  - `oci_core_vcn_dns_resolver_association` -> `oci_dns_resolver`
- In this run, the second data source did not receive a usable `resolver_id` at apply time.
- Updated `dns.tf` to use a more robust resolver lookup pattern:
  - replaced association+single resolver data source with `data "oci_dns_resolvers"` filtered by `attached_vcn_id`
  - resolved view id dynamically via:
    - `try(data.oci_dns_resolvers.main.resolvers[0].default_view_id, null)`
  - still honors explicit override via `var.private_dns_view_id`.

#### Validation after fix
- `terraform validate -no-color` passes.
- `terraform plan -no-color -lock=false` runs without the prior DNS `resolver_id` argument error.

#### Runtime continuity notes (manual operations)
- If lock error appears, wait for active run to finish; if no run is active, release stale lock:
  - `terraform force-unlock <LOCK_ID>`
- If GoldenGate connection is marked tainted due prior reflection timeout, clear and retry:
  - `terraform untaint 'oci_golden_gate_connection.mysql_green_connection[0]'`

#### Resume-later commands
```bash
terraform validate -no-color
terraform force-unlock 57a04346-7ce5-3890-36de-f079130dfc82   # only if no active Terraform run
terraform untaint 'oci_golden_gate_connection.mysql_green_connection[0]'
terraform plan -no-color
terraform apply -no-color
```

### 2026-03-01 — End-to-end sequencing/idempotency hardening (DNS + GoldenGate)

#### User concern addressed
- Repeated apply/destroy friction around DNS and GoldenGate led to a full dependency-flow audit to ensure IDs are populated only after prerequisite resource creation.

#### Terraform sequencing model verified
- Effective chain in this stack is:
  1. Network + MySQL
  2. GoldenGate deployment (depends on both MySQL DB systems)
  3. GoldenGate connections (depend on deployment)
  4. GoldenGate assignments (depend on deployment + corresponding connection)
  5. Private DNS zone + RRsets (depend on zone and target IP providers)

#### Hardening changes implemented
1. **DNS robustness (`dns.tf`)**
   - Replaced brittle resolver-id chain with `data "oci_dns_views"` lookup for `scope = "PRIVATE"`.
   - Effective view resolution now uses:
     - explicit `var.private_dns_view_id` when provided, else first discovered PRIVATE view.
   - Added conditional creation guard:
     - DNS zone + RRsets are created only when a usable private DNS view id is available.
   - Updated outputs to handle optional DNS-zone creation safely (`try(..., null)`).

2. **GoldenGate stability (`goldengate.tf`)**
   - Added `trigger_refresh = false` on both GG connections to reduce replacement churn.
   - Increased GG connection timeouts to `90m` (create/update/delete).
   - Increased GG assignment timeouts to `60m` (create/update/delete).
   - Expanded explicit `depends_on` for assignment resources to enforce deterministic create ordering.

#### Validation checkpoint after hardening
- `terraform validate -no-color` passes.
- `terraform plan -no-color -lock=false` passes without prior DNS `resolver_id` error.
- `terraform untaint 'oci_golden_gate_connection.mysql_green_connection[0]'` executed; plan no longer forces green connection replacement in this run.

#### Operational caveat retained
- OCI provider polling for long-running GoldenGate operations may still intermittently emit reflection/timeouts.
- This is handled with the documented manual recovery runbooks (verify OCI lifecycle, reconcile stale state only when OCI confirms `DELETED`, retry apply/destroy).

### 2026-03-01 — Shared OCI MySQL configuration for Blue/Green (GoldenGate 23ai logical replication readiness)

- Added shared MySQL configuration resource:
  - `oci_mysql_mysql_configuration.shared_logical_replication`
- Added dynamic parent configuration resolution:
  - `data.oci_mysql_mysql_configurations.default_for_shape`
  - fallback/override via `mysql_configuration_parent_id`
- Attached shared configuration to both DB systems:
  - `oci_mysql_mysql_db_system.green.configuration_id`
  - `oci_mysql_mysql_db_system.blue.configuration_id`
- Added replication-focused config variables:
  - `mysql_config_binlog_expire_logs_seconds`
  - `mysql_config_binlog_row_metadata`
  - `mysql_config_binlog_transaction_compression`
  - `mysql_config_replica_parallel_workers`
- Added guardrail precondition for parent configuration discovery failures with explicit remediation guidance.
- Propagated new variables to templates/env files and Resource Manager schema:
  - `terraform.tfvars.example`
  - `deployment.tfvars.template`
  - `env/dev.tfvars`, `env/test.tfvars`, `env/prod.tfvars`
  - `schema.yaml`

### 2026-03-02 — Temporary disablement of GoldenGate connections/assignments (stability mode)

- User-requested rollback applied for stability during stack apply runs.
- In `goldengate.tf`, GoldenGate connection resources and connection-assignment resources are commented out/disabled.
- GoldenGate deployment resource remains active (controlled by `goldengate_enabled`).
- Output behavior updated in `outputs.tf`:
  - `goldengate_mysql_connection_id = null`
  - `goldengate_mysql_blue_connection_id = null`
  - `goldengate_connection_assignment_id = null`
  - `goldengate_blue_connection_assignment_id = null`
- Variable templates and docs aligned with temporary mode:
  - `terraform.tfvars.example`
  - `deployment.tfvars.template`
  - `README.md`
  - `TERRAFORM_DEPLOYMENT.md`
  - `specifications.md`

#### Temporary-mode operational expectation
- When `goldengate_enabled = true`, Terraform creates only the GoldenGate deployment.
- Connection-related variables are retained for future re-enable, but currently not used by active resources.

---

## 4) Troubleshooting

### Exact errors observed
- `Error: could not infer resource state via reflection`
- `Error acquiring the state lock`
- `Error: Missing required argument` (`resolver_id`)
- `Error in function call ... Call to function "coalesce" failed: no non-null, non-empty-string arguments`

### Manual apply recovery
1. Validate and inspect pending drift:
   ```bash
   terraform validate -no-color
   terraform plan -no-color
   ```
2. If lock is stale and no Terraform run is active:
   ```bash
   terraform force-unlock <LOCK_ID>
   ```
3. If GoldenGate connection is tainted after reflection failure:
   ```bash
   terraform untaint 'oci_golden_gate_connection.mysql_green_connection[0]'
   terraform untaint 'oci_golden_gate_connection.mysql_blue_connection[0]'
   ```
4. Resume apply:
   ```bash
   terraform apply -auto-approve -no-color -lock-timeout=30m
   ```
5. If only one pending GG resource remains, use targeted recovery then re-check full convergence:
   ```bash
   terraform apply -auto-approve -no-color -lock-timeout=30m -target='oci_golden_gate_connection_assignment.mysql_blue_connection_assignment[0]'
   terraform plan -no-color
   ```

### Manual destroy recovery
1. Start normal destroy:
   ```bash
   terraform destroy -auto-approve -no-color
   ```
2. If reflection error appears, verify OCI lifecycle (`DELETING`/`DELETED`) for impacted GG/MySQL resources.
3. If OCI confirms a resource is already `DELETED`, remove stale state only for that resource:
   ```bash
   terraform state rm <resource-address>
   ```
4. Re-run destroy and verify clean end state:
   ```bash
   terraform destroy -auto-approve -no-color
   terraform state list
   terraform plan -destroy -no-color
   terraform plan -no-color
   ```
