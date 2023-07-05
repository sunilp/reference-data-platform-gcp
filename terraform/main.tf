# =============================================================================
# Reference Data Platform — Core Infrastructure
# =============================================================================
# This is the root module that composes the data platform infrastructure.
# Each component is modularized for independent management and testing.
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }

  # In production, use a GCS backend for remote state with encryption
  # backend "gcs" {
  #   bucket  = "your-terraform-state-bucket"
  #   prefix  = "data-platform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# -----------------------------------------------------------------------------
# Data warehouse layer — BigQuery datasets for each platform layer
# Separation of datasets enables independent access control and lifecycle
# management per data layer (raw, staging, vault, marts).
# -----------------------------------------------------------------------------
module "bigquery" {
  source = "./modules/bigquery"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  kms_key_id = var.kms_key_id

  raw_dataset_id     = var.raw_dataset_id
  staging_dataset_id = var.staging_dataset_id
  vault_dataset_id   = var.vault_dataset_id
  marts_dataset_id   = var.marts_dataset_id

  data_retention_days = var.data_retention_days

  # Access control — restrict who can read each layer
  raw_readers     = var.raw_readers
  staging_readers = var.staging_readers
  vault_readers   = var.vault_readers
  marts_readers   = var.marts_readers
}

# -----------------------------------------------------------------------------
# Ingestion layer — Dataflow pipelines for streaming and batch ingestion
# Dataflow provides exactly-once processing guarantees and auto-scaling,
# which is critical for reliable data ingestion in regulated environments.
# -----------------------------------------------------------------------------
module "dataflow" {
  source = "./modules/dataflow"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  network    = var.network
  subnetwork = var.subnetwork

  service_account_email = var.dataflow_service_account_email

  temp_bucket_name    = var.dataflow_temp_bucket
  staging_bucket_name = var.dataflow_staging_bucket

  bigquery_raw_dataset = module.bigquery.raw_dataset_id
}

# -----------------------------------------------------------------------------
# Orchestration layer — Cloud Composer (managed Airflow)
# Composer provides DAG-based orchestration with built-in dependency
# management, retry logic, SLA monitoring, and alerting.
# Chosen over Cloud Functions for complex multi-step pipeline orchestration.
# See docs/design-decisions.md for rationale.
# -----------------------------------------------------------------------------
module "composer" {
  source = "./modules/composer"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  network    = var.network
  subnetwork = var.subnetwork

  service_account_email = var.composer_service_account_email

  kms_key_id = var.kms_key_id

  composer_image_version = var.composer_image_version

  # Sizing — adjust based on workload
  scheduler_cpu    = var.composer_scheduler_cpu
  scheduler_memory = var.composer_scheduler_memory
  worker_cpu       = var.composer_worker_cpu
  worker_memory    = var.composer_worker_memory
  worker_min_count = var.composer_worker_min_count
  worker_max_count = var.composer_worker_max_count
}
