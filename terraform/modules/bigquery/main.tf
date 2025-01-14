# =============================================================================
# BigQuery Module — Data Warehouse Layer
# =============================================================================
# Creates four datasets representing the data platform layers:
#   raw     → Landing zone for ingested data (append-only)
#   staging → Cleansed and validated data
#   vault   → Data Vault 2.0 models (hubs, links, satellites)
#   marts   → Business-ready consumption views
#
# Each dataset has independent access controls, encryption, and retention.
# =============================================================================

variable "project_id" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "kms_key_id" { type = string }
variable "raw_dataset_id" { type = string }
variable "staging_dataset_id" { type = string }
variable "vault_dataset_id" { type = string }
variable "marts_dataset_id" { type = string }
variable "data_retention_days" { type = number }
variable "raw_readers" { type = list(string) }
variable "staging_readers" { type = list(string) }
variable "vault_readers" { type = list(string) }
variable "marts_readers" { type = list(string) }

locals {
  datasets = {
    raw = {
      dataset_id  = "${var.raw_dataset_id}_${var.environment}"
      description = "Landing zone for raw ingested data. Append-only, immutable."
      readers     = var.raw_readers
      labels = {
        layer       = "raw"
        environment = var.environment
        data_class  = "restricted"
      }
    }
    staging = {
      dataset_id  = "${var.staging_dataset_id}_${var.environment}"
      description = "Cleansed and validated data. Schema-enforced, quality-tested."
      readers     = var.staging_readers
      labels = {
        layer       = "staging"
        environment = var.environment
        data_class  = "restricted"
      }
    }
    vault = {
      dataset_id  = "${var.vault_dataset_id}_${var.environment}"
      description = "Data Vault 2.0 models — hubs, links, satellites. Full history."
      readers     = var.vault_readers
      labels = {
        layer       = "vault"
        environment = var.environment
        data_class  = "restricted"
      }
    }
    marts = {
      dataset_id  = "${var.marts_dataset_id}_${var.environment}"
      description = "Business-ready consumption views. Aggregated, denormalized."
      readers     = var.marts_readers
      labels = {
        layer       = "marts"
        environment = var.environment
        data_class  = "internal"
      }
    }
  }
}

# --- Datasets ----------------------------------------------------------------

resource "google_bigquery_dataset" "datasets" {
  for_each = local.datasets

  project    = var.project_id
  dataset_id = each.value.dataset_id
  location   = var.region

  friendly_name = "${each.key} (${var.environment})"
  description   = each.value.description

  # Default table expiration — raw data expires after retention period.
  # Vault and marts tables do not expire (managed by dbt lifecycle).
  default_table_expiration_ms = each.key == "raw" ? var.data_retention_days * 86400000 : null

  labels = each.value.labels

  # Customer-managed encryption key
  dynamic "default_encryption_configuration" {
    for_each = var.kms_key_id != null ? [1] : []
    content {
      kms_key_name = var.kms_key_id
    }
  }

  # Prevent accidental deletion in production
  delete_contents_on_destroy = var.environment != "prod"
}

# --- IAM Bindings (Read Access) ----------------------------------------------
# Each dataset has independent read access controls.
# Write access is limited to service accounts (Dataflow for raw, dbt for others).

resource "google_bigquery_dataset_iam_member" "readers" {
  for_each = {
    for pair in flatten([
      for ds_key, ds_val in local.datasets : [
        for reader in ds_val.readers : {
          key       = "${ds_key}-${reader}"
          dataset   = ds_key
          member    = reader
        }
      ]
    ]) : pair.key => pair
  }

  project    = var.project_id
  dataset_id = google_bigquery_dataset.datasets[each.value.dataset].dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = each.value.member
}

# --- Audit Logging -----------------------------------------------------------
# BigQuery audit logs are enabled by default in GCP. This ensures
# DATA_READ and DATA_WRITE operations are captured for all datasets.
# In production, these logs should be exported to a separate audit project.

# --- Outputs -----------------------------------------------------------------

output "raw_dataset_id" {
  value = google_bigquery_dataset.datasets["raw"].dataset_id
}

output "staging_dataset_id" {
  value = google_bigquery_dataset.datasets["staging"].dataset_id
}

output "vault_dataset_id" {
  value = google_bigquery_dataset.datasets["vault"].dataset_id
}

output "marts_dataset_id" {
  value = google_bigquery_dataset.datasets["marts"].dataset_id
}

