# Terraform Deployment Guide (Detailed)

This guide explains how to deploy the stack in a repeatable way for any OCI environment/tenancy.

## 1) What this stack deploys

- 1 VCN
- 2 subnets only:
  - Public subnet (Bastion)
  - Private subnet (MySQL + GoldenGate + Private NLB)
- OCI MySQL HA DB System (`8.0.45`, `MySQL.2`, `50GB`, hostname `mysql-green`)
- Bastion Compute (`2 OCPU`, `16 GB RAM`) + attached `200 GB` block volume
- Private NLB with MySQL backend on port `3306`
- OCI GoldenGate deployment + MySQL connection

---

## 2) Prerequisites

1. Terraform installed (`>= 1.5`)
2. OCI CLI configured with a working profile (usually `DEFAULT`)
3. Permissions to create networking, compute, MySQL, NLB, and GoldenGate resources

Quick checks:

```bash
terraform -version
oci iam region list --all
```

---

## 3) Prepare deployment variables

Use the reusable template:

```bash
cp deployment.tfvars.template env-dev.tfvars
```

Or use pre-created files in `env/`:
- `env/dev.tfvars`
- `env/test.tfvars`
- `env/prod.tfvars`

Edit `env-dev.tfvars` and set at minimum:

- `tenancy_ocid`
- `compartment_ocid`
- `region`
- `ssh_public_key`
- `mysql_admin_password`
- `goldengate_admin_password`

Optional:

- `availability_domain` (if omitted, stack tries to auto-discover first AD)
- CIDRs, names, shape overrides

---

## 4) Initialize

```bash
terraform init -upgrade
```

---

## 5) Validate

```bash
terraform validate
```

---

## 6) Plan

```bash
terraform plan -input=false -var-file=env-dev.tfvars
```

If plan looks good and you want to lock it:

```bash
terraform plan -input=false -var-file=env-dev.tfvars -out=tfplan
```

---

## 7) Apply

From saved plan:

```bash
terraform apply tfplan
```

Or directly:

```bash
terraform apply -input=false -var-file=env-dev.tfvars
```

---

## 8) View outputs

```bash
terraform output
```

Important outputs include:

- `mysql_db_system_ip`
- `mysql_db_system_endpoint`
- `bastion_public_ip`
- `nlb_private_ip`
- GoldenGate resource IDs

---

## 9) Reuse for another tenancy/environment

Create another var file:

```bash
cp deployment.tfvars.template env-prod.tfvars
```

Update values and deploy:

```bash
terraform plan  -input=false -var-file=env-prod.tfvars
terraform apply -input=false -var-file=env-prod.tfvars
```

For different tenancies/accounts, keep one tfvars per account and run with that file explicitly:

```bash
terraform plan  -input=false -var-file=env/dev.tfvars
terraform plan  -input=false -var-file=env/test.tfvars
terraform plan  -input=false -var-file=env/prod.tfvars
```

The selected `-var-file` fully controls which tenancy/compartment/region and credentials are used.

---

## 10) OCI Resource Manager usage

1. Zip this folder content.
2. Create stack in OCI Resource Manager.
3. Upload zip and fill variables from your environment var-file values.
4. Run Plan and Apply job.

Note:
- For Resource Manager auth, set `oci_auth = "ResourcePrincipal"`.
- For local CLI/API key usage, keep `oci_auth = "ApiKey"`.

---

## 11) Troubleshooting

### A) `OCI_RESOURCE_PRINCIPAL_VERSION not present`
- Cause: using `ResourcePrincipal` outside supported service runtime.
- Fix: set `oci_auth = "ApiKey"` for local runs.

### B) Availability Domain issues
- If AD lookup fails, set `availability_domain` explicitly in var-file.

### C) Provider/auth issues
- Ensure OCI CLI profile works:

```bash
oci os ns get --profile DEFAULT
```

---

## 12) Security recommendation

- Do not commit real passwords in `*.tfvars`.
- Prefer OCI Vault + secret IDs for production.
