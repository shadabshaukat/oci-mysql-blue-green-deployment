# OCI MySQL Channel Replication (A -> B) for Blue/Green Upgrade

This guide captures the 3 OCI CLI commands to:
1. Create a manual backup from existing DB System **A**
2. Create new DB System **B** from that backup (new name/hostname, target version)
3. Create MySQL Channel replication **A -> B**

---

## 1) Create manual backup from existing DB System A

```bash
oci mysql backup create \
  --db-system-id <DBSYSTEM_A_OCID> \
  --backup-type FULL \
  --display-name "A-manual-backup-$(date +%Y%m%d-%H%M%S)" \
  --wait-for-state SUCCEEDED \
  --max-wait-seconds 7200
```

---

## 2) Create new DB System B from backup

> Uses backup from step 1, with a different DB System name/hostname and requested target MySQL version.

```bash
oci mysql db-system create \
  --compartment-id <COMPARTMENT_OCID> \
  --subnet-id <PRIVATE_SUBNET_OCID> \
  --shape-name "MySQL.2" \
  --display-name "MySQL-Blue-B" \
  --hostname-label "mysql-blue-b" \
  --admin-username admin \
  --admin-password '<STRONG_ADMIN_PASSWORD>' \
  --is-highly-available true \
  --availability-domain '<AD_NAME>' \
  --source '{"sourceType":"BACKUP","backupId":"<BACKUP_OCID_FROM_STEP1>"}' \
  --mysql-version '<TARGET_VERSION>' \
  --wait-for-state ACTIVE \
  --max-wait-seconds 14400
```

---

## 3) Create channel replication A -> B

```bash
oci mysql channel create-from-mysql \
  --compartment-id <COMPARTMENT_OCID> \
  --target-db-system-id <DBSYSTEM_B_OCID> \
  --display-name "A-to-B-channel" \
  --is-enabled true \
  --source-hostname <DBSYSTEM_A_PRIVATE_IP_OR_FQDN> \
  --source-port 3306 \
  --source-username <REPLICATION_USER_ON_A> \
  --source-password '<REPLICATION_USER_PASSWORD>' \
  --source-ssl-mode REQUIRED \
  --target-channel-name a_to_b \
  --wait-for-state SUCCEEDED \
  --max-wait-seconds 3600
```

---

## Will this strategy work?

Yes — this is a strong blue/green strategy for lower-version -> higher-version migration with controlled cutover.

### Important caveat

Depending on OCI/MySQL version path rules, restoring from backup and forcing a different major version in the same create command may be restricted.

If command #2 rejects `--mysql-version` with backup restore, use this fallback:
1. Create B as a fresh DB System at target version (`sourceType = NONE`)
2. Create channel replication A -> B for CDC
3. Keep the manual backup from step 1 as rollback/safety checkpoint

---

## Pre-checks before creating channel replication

- On A, ensure binlog and replication settings are valid for channel replication.
- Ensure replication user on A exists with required replication privileges.
- Ensure NSG/Security List/network routing allows B to reach A on port `3306`.
- For major version upgrades, run compatibility tests and validation before cutover.

---

## Optional helpful verification commands

```bash
# List backups for source DB System A
oci mysql backup list --compartment-id <COMPARTMENT_OCID> --db-system-id <DBSYSTEM_A_OCID>

# Get DB System B details after create
oci mysql db-system get --db-system-id <DBSYSTEM_B_OCID>

# List channels targeting DB System B
oci mysql channel list --compartment-id <COMPARTMENT_OCID> --db-system-id <DBSYSTEM_B_OCID>
```
