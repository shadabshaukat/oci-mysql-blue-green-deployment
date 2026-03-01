# Building Blue/Green Deployments for OCI MySQL with Terraform, GoldenGate, NLB, and Private DNS

## Why this pattern matters

OCI MySQL HeatWave DB System is powerful for managed MySQL, but many enterprise teams still need an opinionated **blue/green deployment model** for controlled cutovers, validation windows, and rollback safety. This is especially common when migration and release workflows rely on logical replication and application-level traffic steering.

This guide shows a production-oriented Terraform implementation that creates:

- **Green (staging) MySQL** on version **8.4.8 LTS**
- **Blue (production) MySQL** on version **8.0.45**
- One OCI GoldenGate deployment with **both MySQL connections assigned**
- One private OCI NLB with **both DB backends**
- OCI Private DNS records for app routing and validation paths

The result is a reusable stack that can be applied across environments with only tfvars changes.

---

## Target architecture

### Network
- Single VCN
- Public subnet for bastion
- Private subnet for both MySQL systems, GoldenGate, and private NLB

### Data tier
- `MySQL-Green` (staging): 8.4.8 LTS
- `MySQL-Blue` (production): 8.0.45
- Same shape/storage profile for predictable behavior and performance comparisons

### Replication/orchestration tier
- `OCI-Goldengate-MySQL-OGG` deployment
- Green connection + assignment
- Blue connection + assignment

### Connectivity tier
- Single private NLB backend set
- Backend targets:
  - Green DB private IP
  - Blue DB private IP

### Service discovery tier (Private DNS)
- `nlb-app.mysql.local` → NLB private IP (main app endpoint)
- `nlb-app-green.mysql.local` → Green DB private IP (validation/read-only path)
- `nlb-app-blue.mysql.local` → Blue DB private IP (direct prod endpoint)

---

## Naming and tagging strategy

To avoid confusion, resource names avoid the string `blue-green` in operational identifiers.

- Green tag: `green-staging`
- Blue tag: `blue-prod`
- MySQL names: `MySQL-Green`, `MySQL-Blue`
- GoldenGate name: `OCI-Goldengate-MySQL-OGG`

This makes dashboards, logs, and operational runbooks much easier to interpret during cutover events.

---

## Terraform implementation highlights

## 1) Dual MySQL resources

Two `oci_mysql_mysql_db_system` resources are defined:

- `oci_mysql_mysql_db_system.green` with `mysql_green_version = "8.4.8"`
- `oci_mysql_mysql_db_system.blue` with `mysql_blue_version = "8.0.45"`

Both are HA-enabled and share the same shape/storage profile.

## 2) GoldenGate dual connections + assignments

One GoldenGate deployment is created, and both DB environments are connected and assigned:

- `oci_golden_gate_connection.mysql_green_connection`
- `oci_golden_gate_connection.mysql_blue_connection`
- `oci_golden_gate_connection_assignment.mysql_connection_assignment`
- `oci_golden_gate_connection_assignment.mysql_blue_connection_assignment`

This keeps replication/cutover wiring in code and repeatable across environments.

## 3) NLB with both DB backends

NLB keeps a single backend set on port 3306, with two backends:

- Green DB IP
- Blue DB IP

Traffic orchestration can then be controlled centrally without rewriting application connection strings.

## 4) Private DNS zone + A records

Terraform creates a private DNS zone and three A records to separate runtime app path from validation paths.

This gives clean operational semantics:

- app default endpoint
- blue direct endpoint
- green direct endpoint

---

## Environment portability

The stack is dynamic across environments using tfvars:

- `deployment.tfvars.template`
- `terraform.tfvars.example`
- `env/dev.tfvars`, `env/test.tfvars`, `env/prod.tfvars`

You can keep the same Terraform code and vary:

- compartment/tenancy
- CIDRs
- passwords
- naming prefixes
- optional DNS hostnames/TTL

---

## Validation workflow

Recommended pre-apply checks:

```bash
terraform fmt -recursive
terraform validate
terraform plan -no-color
```

In this implementation, validation succeeded and plan showed full creation of dual MySQL + GoldenGate + NLB + DNS resources.

---

## Operational cutover model

Typical release flow:

1. Blue serves production traffic.
2. Replicate to Green and validate with read-only/test traffic (`nlb-app-green.mysql.local`).
3. Promote Green in change window.
4. Route app endpoint (`nlb-app.mysql.local`) according to policy.
5. Keep Blue available for rollback if needed.

---

## Promotion automation strategy (minimum app impact)

For production-grade blue/green operations, promotion should be orchestrated to minimize dropped connections and transaction risk.

### Desired runtime behavior
- Keep `nlb-app.mysql.local` as the stable application endpoint.
- Ensure only one backend is active for write traffic at a time.
- Use controlled cutover with explicit health and lag gates.

### Strategy A (recommended): NLB drain-based cutover orchestration
1. Keep Blue as active writer while Green stays in validation.
2. During promotion, set old backend to drain mode and keep new backend online.
3. Wait for grace/drain window (for example 30–120 seconds) and live connection reduction.
4. Mark old backend offline and keep rollback ready by preserving fast re-enable workflow.

Common implementation options:
- OCI Functions + OCI Events + OCI DevOps pipeline
- GitHub Actions/Jenkins calling OCI CLI or SDK
- Terraform promotion stage toggles (separate from baseline infra provisioning)

### Strategy B: DNS-assisted cutover
- Keep app endpoint stable at `nlb-app.mysql.local` and use low TTL (default `30`).
- Use DNS change as a secondary control plane, not the primary one.
- Prefer NLB drain as primary mechanism to avoid abrupt reconnect storms.

### Strategy C: Progressive traffic shifting
- Route a controlled subset of sessions to Green (if app/proxy supports canary).
- Validate error rate, latency, and business KPI behavior before full promotion.
- Promote only when SLO gates pass.

---

## Initial load and CDC options (Blue -> Green)

### Option 1: OCI GoldenGate (preferred)
- Run initial load into Green.
- Enable continuous CDC from Blue to Green.
- Enforce validation gates:
  - replication lag threshold,
  - DDL/DML compatibility,
  - table-level row count/checksum checks.

### Option 2: Native MySQL channel replication
- Configure GTID-based async replication Blue -> Green.
- Monitor lag and test failover runbook.
- Lower operational complexity, but less flexibility than GoldenGate for transformation/filtering use cases.

#### Recommended enterprise pattern
- Primary path: GoldenGate for initial load + CDC.
- Optional fallback: native MySQL replication for simpler estates.
- Promotion gates should always include:
  - data consistency pass,
  - lag threshold pass,
  - application read/write smoke pass,
  - pre-defined rollback criteria.

---

## Lessons learned

- GoldenGate API/provider behavior can occasionally produce transient reflection/state errors; keep continuity logs in specs.
- Explicit naming/tagging dramatically simplifies troubleshooting in multi-environment OCI estates.
- Private DNS plus NLB gives a practical abstraction layer for application traffic orchestration.

---

## Final thoughts

If you already built this model for OCI PostgreSQL, this MySQL adaptation follows the same enterprise principles: immutable infrastructure, deterministic naming, dynamic environment overlays, and controlled traffic/data cutover.

For heavy MySQL customers, this pattern provides a concrete foundation for safer releases and migration orchestration where native blue/green controls are not enough on their own.
