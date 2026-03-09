# Blue-to-Green Replication Automation

This folder contains automation for OCI MySQL blue/green replication bootstrap using OCI CLI:

- `Blue-to-Green-Replication-Setup` (full workflow script)
- `Blue-to-Green-Replication-Reuse-Staging` (reuse-existing-target variant)
- `sample-input-blue-to-staging.json` (example non-interactive input for full workflow)
- `sample-input-reuse-existing-staging.json` (example non-interactive input for reuse-existing-target variant)

## What the script does

1. Creates manual backup from source DB System A (your `MySQL-Blue`, 8.0.45).
2. Waits/polls until backup is `ACTIVE`.
3. Creates target DB System B from that backup (your `MySQL-Staging`, 8.4.8 target).
4. Waits/polls until target DB is `ACTIVE`.
5. Creates channel replication A -> B.
6. Waits/polls until channel is `ACTIVE`.

This is ideal when you want to programmatically build a fresh blue/green test chain from a known source (`MySQL-Blue`) to a new or rebuilt target (`MySQL-Staging`) and verify readiness before testing cutover.

---

## Variant: Reuse existing MySQL-Staging (skip DB create)

Use this variant when `MySQL-Staging` already exists and you only want to (re)create channel replication:

- Script: `Blue-to-Green-Replication-Reuse-Staging`
- It **does not** create a backup.
- It **does not** create a new DB system.
- It validates source/target DB availability and creates replication channel Blue -> Staging.
- It polls channel until `ACTIVE`.

### How this helps Blue-Green testing for OCI MySQL

This mode is useful for iterative blue/green test cycles where infrastructure already exists and you only need to reset/restart CDC wiring:

- Faster turnaround for replication testing and failover rehearsals.
- Reduced OCI resource churn and lower provisioning wait time.
- Good for repeated validation of replication lag, schema compatibility, and app read/write behavior before final cutover.

---

## Prerequisites

- OCI CLI installed and authenticated.
- `jq` installed.
- OCI IAM permissions for MySQL backup, db-system create/get, and channel create/get.
- Network access from target DB to source DB on MySQL port (default 3306).
- Replication user on source DB with required privileges.

---

## Make executable

```bash
chmod +x /Users/shadab/Downloads/MySQL-Green-Blue-Deployment/replication-automation/Blue-to-Green-Replication-Setup
chmod +x /Users/shadab/Downloads/MySQL-Green-Blue-Deployment/replication-automation/Blue-to-Green-Replication-Reuse-Staging
```

---

## Interactive run

```bash
/Users/shadab/Downloads/MySQL-Green-Blue-Deployment/replication-automation/Blue-to-Green-Replication-Setup
```

Reuse-existing-staging variant:

```bash
/Users/shadab/Downloads/MySQL-Green-Blue-Deployment/replication-automation/Blue-to-Green-Replication-Reuse-Staging
```

---

## Non-interactive run (flags)

Example aligned to your environment/profile and Blue -> Staging flow:

```bash
/Users/shadab/Downloads/MySQL-Green-Blue-Deployment/replication-automation/Blue-to-Green-Replication-Setup \
  --non-interactive --yes \
  --profile DEFAULT \
  --config-file /Users/shadab/.oci/config \
  --region ap-tokyo-1 \
  --compartment-id ocid1.compartment.oc1..aaaaaaaacoqxp2n77ra2343maw2px4rlrtzqaw5ord6be2cbrbwlrpqwegxa \
  --db-a-id <MYSQL_BLUE_DB_OCID> \
  --backup-display-name Blue-manual-backup-$(date +%Y%m%d-%H%M%S) \
  --backup-type FULL \
  --target-subnet-id <TARGET_PRIVATE_SUBNET_OCID> \
  --target-shape MySQL.2 \
  --target-display-name MySQL-Staging \
  --target-hostname mysql-staging \
  --target-admin-username admin \
  --target-admin-password '<TARGET_ADMIN_PASSWORD>' \
  --target-is-ha true \
  --target-ad '<AP_TOKYO_AD_NAME>' \
  --target-mysql-version 8.4.8 \
  --source-hostname <MYSQL_BLUE_PRIVATE_IP_OR_FQDN> \
  --source-port 3306 \
  --repl-user <REPLICATION_USER_ON_BLUE> \
  --repl-password '<REPLICATION_USER_PASSWORD>' \
  --source-ssl-mode REQUIRED \
  --channel-display-name Blue-to-Staging-channel \
  --channel-name blue_to_staging
```

---

## Non-interactive run (JSON input)

Use provided sample file and override placeholders:

```bash
/Users/shadab/Downloads/MySQL-Green-Blue-Deployment/replication-automation/Blue-to-Green-Replication-Setup \
  --non-interactive --yes \
  --input-file /Users/shadab/Downloads/MySQL-Green-Blue-Deployment/replication-automation/sample-input-blue-to-staging.json
```

Reuse-existing-staging variant:

```bash
/Users/shadab/Downloads/MySQL-Green-Blue-Deployment/replication-automation/Blue-to-Green-Replication-Reuse-Staging \
  --non-interactive --yes \
  --input-file /Users/shadab/Downloads/MySQL-Green-Blue-Deployment/replication-automation/sample-input-reuse-existing-staging.json
```

## Non-interactive run (flags) for reuse-existing-staging variant

```bash
/Users/shadab/Downloads/MySQL-Green-Blue-Deployment/replication-automation/Blue-to-Green-Replication-Reuse-Staging \
  --non-interactive --yes \
  --profile DEFAULT \
  --config-file /Users/shadab/.oci/config \
  --region ap-tokyo-1 \
  --compartment-id ocid1.compartment.oc1..aaaaaaaacoqxp2n77ra2343maw2px4rlrtzqaw5ord6be2cbrbwlrpqwegxa \
  --source-db-id <MYSQL_BLUE_DB_OCID> \
  --target-db-id <MYSQL_STAGING_DB_OCID> \
  --source-hostname <MYSQL_BLUE_PRIVATE_IP_OR_FQDN> \
  --source-port 3306 \
  --repl-user <REPLICATION_USER_ON_BLUE> \
  --repl-password '<REPLICATION_USER_PASSWORD>' \
  --source-ssl-mode REQUIRED \
  --channel-display-name Blue-to-Staging-channel \
  --channel-name blue_to_staging
```

---

## Check help

```bash
/Users/shadab/Downloads/MySQL-Green-Blue-Deployment/replication-automation/Blue-to-Green-Replication-Setup --help
/Users/shadab/Downloads/MySQL-Green-Blue-Deployment/replication-automation/Blue-to-Green-Replication-Reuse-Staging --help
```

---

## Notes

- If OCI rejects `--mysql-version` when restoring from backup (version path restriction), run without `target_mysql_version` and validate the created version/path strategy.
- For CI/CD, prefer `--non-interactive --yes` with `--input-file` plus secret injection via your pipeline secret manager.
