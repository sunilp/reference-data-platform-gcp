# =============================================================================
# Cloud Composer Module — Orchestration Layer
# =============================================================================
# Deploys a Cloud Composer 2 (managed Airflow) environment.
#
# Enterprise configuration:
#   - Private IP only (no public endpoint)
#   - Customer-managed encryption keys (CMEK)
#   - Maintenance windows during off-peak hours
#   - Auto-scaling workers with defined bounds
#   - Resilience mode enabled for HA
# =============================================================================

variable "project_id" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "network" { type = string }
variable "subnetwork" { type = string }
variable "service_account_email" { type = string }
variable "kms_key_id" { type = string }
variable "composer_image_version" { type = string }
variable "scheduler_cpu" { type = number }
variable "scheduler_memory" { type = number }
variable "worker_cpu" { type = number }
variable "worker_memory" { type = number }
variable "worker_min_count" { type = number }
variable "worker_max_count" { type = number }

resource "google_composer_environment" "data_platform" {
  provider = google-beta
  name     = "data-platform-${var.environment}"
  project  = var.project_id
  region   = var.region

  labels = {
    environment = var.environment
    purpose     = "data-platform-orchestration"
  }

  config {
    # --- Software Configuration ---
    software_config {
      image_version = var.composer_image_version

      # Airflow configuration overrides
      airflow_config_overrides = {
        # Core settings
        "core-dags_are_paused_at_creation" = "true"
        "core-max_active_runs_per_dag"     = "1"

        # Prevent DAGs from running on scheduler restart
        "scheduler-catchup_by_default" = "false"

        # Email alerting for SLA misses
        "email-email_backend" = "airflow.utils.email.send_email_smtp"

        # Security — disable example DAGs in production
        "core-load_examples" = "false"
      }

      # Python packages for DAGs
      pypi_packages = {
        "dbt-bigquery"        = ">=1.7,<1.9"
        "soda-core-bigquery"  = ">=3.0,<4.0"
        "slack-sdk"           = ">=3.0"
      }
    }

    # --- Workloads Configuration ---
    workloads_config {
      scheduler {
        cpu        = var.scheduler_cpu
        memory_gb  = var.scheduler_memory
        storage_gb = 5
        count      = var.environment == "prod" ? 2 : 1 # HA scheduler in prod
      }

      web_server {
        cpu        = 2
        memory_gb  = 4
        storage_gb = 5
      }

      worker {
        cpu        = var.worker_cpu
        memory_gb  = var.worker_memory
        storage_gb = 10
        min_count  = var.worker_min_count
        max_count  = var.worker_max_count
      }
    }

    # --- Environment Configuration ---
    environment_size = var.environment == "prod" ? "ENVIRONMENT_SIZE_LARGE" : "ENVIRONMENT_SIZE_MEDIUM"

    # Resilience mode for production — enables HA and zone redundancy
    resilience_mode = var.environment == "prod" ? "HIGH_RESILIENCE" : "STANDARD_RESILIENCE"

    # --- Node Configuration ---
    node_config {
      network    = var.network
      subnetwork = var.subnetwork

      service_account = var.service_account_email

      # Private IP — no public endpoint
      enable_ip_masq_agent = true
    }

    # --- Private Environment ---
    private_environment_config {
      enable_private_endpoint              = true
      enable_privately_used_public_ips     = false
      cloud_sql_ipv4_cidr_block           = "10.0.0.0/12"
      master_ipv4_cidr_block              = "172.16.0.0/23"
      cloud_composer_network_ipv4_cidr_block = "172.31.245.0/24"
    }

    # --- Encryption ---
    dynamic "encryption_config" {
      for_each = var.kms_key_id != null ? [1] : []
      content {
        kms_key_name = var.kms_key_id
      }
    }

    # --- Maintenance Window ---
    # Schedule maintenance during off-peak hours (Saturday 2-6 AM UTC)
    maintenance_window {
      start_time = "2024-01-01T02:00:00Z"
      end_time   = "2024-01-01T06:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA"
    }
  }
}

# --- Outputs -----------------------------------------------------------------

output "environment_id" {
  value = google_composer_environment.data_platform.id
}

output "airflow_uri" {
  value = google_composer_environment.data_platform.config[0].airflow_uri
}

output "dag_gcs_prefix" {
  value = google_composer_environment.data_platform.config[0].dag_gcs_prefix
}
