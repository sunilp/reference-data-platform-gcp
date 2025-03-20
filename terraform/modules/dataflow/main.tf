# =============================================================================
# Dataflow Module — Ingestion Layer
# =============================================================================
# Manages GCS buckets for Dataflow temp/staging and provides a template
# for Dataflow Flex Template jobs. Actual job definitions are deployed
# separately via CI/CD.
#
# Design choice: Dataflow over direct Pub/Sub-to-BigQuery for:
#   - Schema validation and data quality checks during ingestion
#   - Dead-letter queue handling for malformed records
#   - Exactly-once processing guarantees
#   - Custom transformation logic (e.g., PII tokenization)
# =============================================================================

variable "project_id" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "network" { type = string }
variable "subnetwork" { type = string }
variable "service_account_email" { type = string }
variable "temp_bucket_name" { type = string }
variable "staging_bucket_name" { type = string }
variable "bigquery_raw_dataset" { type = string }

# --- GCS Buckets for Dataflow ------------------------------------------------

resource "google_storage_bucket" "dataflow_temp" {
  name     = "${var.temp_bucket_name}-${var.environment}"
  project  = var.project_id
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Temp files are transient — auto-delete after 7 days
  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    purpose     = "dataflow-temp"
    environment = var.environment
  }
}

resource "google_storage_bucket" "dataflow_staging" {
  name     = "${var.staging_bucket_name}-${var.environment}"
  project  = var.project_id
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Staging files retained for 30 days for debugging and replay
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }

  labels = {
    purpose     = "dataflow-staging"
    environment = var.environment
  }
}

# --- Dead Letter Queue -------------------------------------------------------
# Records that fail schema validation or transformation are written here
# for investigation and replay.

resource "google_storage_bucket" "dead_letter" {
  name     = "${var.project_id}-dataflow-dlq-${var.environment}"
  project  = var.project_id
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Retain dead-letter records for 90 days
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    purpose     = "dead-letter-queue"
    environment = var.environment
  }
}

# --- Pub/Sub Topic for Streaming Ingestion -----------------------------------

resource "google_pubsub_topic" "ingestion" {
  name    = "data-ingestion-${var.environment}"
  project = var.project_id

  labels = {
    purpose     = "streaming-ingestion"
    environment = var.environment
  }
}

resource "google_pubsub_subscription" "dataflow_ingestion" {
  name    = "dataflow-ingestion-sub-${var.environment}"
  project = var.project_id
  topic   = google_pubsub_topic.ingestion.id

  # Dataflow manages its own checkpointing — set a generous ack deadline
  ack_deadline_seconds = 600

  # Retain unacked messages for 7 days (replay capability)
  retain_acked_messages = true
  message_retention_duration = "604800s"

  expiration_policy {
    ttl = "" # Never expire
  }
}

# --- IAM for Dataflow Service Account ---------------------------------------

resource "google_project_iam_member" "dataflow_worker" {
  project = var.project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${var.service_account_email}"
}

resource "google_storage_bucket_iam_member" "temp_access" {
  bucket = google_storage_bucket.dataflow_temp.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.service_account_email}"
}

resource "google_storage_bucket_iam_member" "staging_access" {
  bucket = google_storage_bucket.dataflow_staging.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.service_account_email}"
}

resource "google_storage_bucket_iam_member" "dlq_access" {
  bucket = google_storage_bucket.dead_letter.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.service_account_email}"
}

# --- Outputs -----------------------------------------------------------------

output "temp_bucket_name" {
  value = google_storage_bucket.dataflow_temp.name
}

output "staging_bucket_name" {
  value = google_storage_bucket.dataflow_staging.name
}

output "dead_letter_bucket_name" {
  value = google_storage_bucket.dead_letter.name
}

output "ingestion_topic_id" {
  value = google_pubsub_topic.ingestion.id
}

output "ingestion_subscription_id" {
  value = google_pubsub_subscription.dataflow_ingestion.id
}

