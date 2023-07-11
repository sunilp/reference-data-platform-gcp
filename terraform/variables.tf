# =============================================================================
# Variables — Reference Data Platform
# =============================================================================

# --- Project & Environment ---------------------------------------------------

variable "project_id" {
  description = "GCP project ID where the data platform will be deployed"
  type        = string
}

variable "region" {
  description = "GCP region for resource deployment"
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Environment identifier (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# --- Encryption --------------------------------------------------------------

variable "kms_key_id" {
  description = "Cloud KMS key ID for customer-managed encryption. Format: projects/{project}/locations/{location}/keyRings/{ring}/cryptoKeys/{key}"
  type        = string
  default     = null
}

# --- Network -----------------------------------------------------------------

variable "network" {
  description = "VPC network self-link for private networking"
  type        = string
}

variable "subnetwork" {
  description = "VPC subnetwork self-link for resource deployment"
  type        = string
}

# --- BigQuery ----------------------------------------------------------------

variable "raw_dataset_id" {
  description = "BigQuery dataset ID for raw (landing) data"
  type        = string
  default     = "raw"
}

variable "staging_dataset_id" {
  description = "BigQuery dataset ID for staging (cleansed) data"
  type        = string
  default     = "staging"
}

variable "vault_dataset_id" {
  description = "BigQuery dataset ID for Data Vault models"
  type        = string
  default     = "vault"
}

variable "marts_dataset_id" {
  description = "BigQuery dataset ID for business consumption marts"
  type        = string
  default     = "marts"
}

variable "data_retention_days" {
  description = "Default data retention period in days. Set based on regulatory requirements."
  type        = number
  default     = 2555 # ~7 years — common regulatory retention period
}

variable "raw_readers" {
  description = "List of IAM members with read access to the raw dataset"
  type        = list(string)
  default     = []
}

variable "staging_readers" {
  description = "List of IAM members with read access to the staging dataset"
  type        = list(string)
  default     = []
}

variable "vault_readers" {
  description = "List of IAM members with read access to the vault dataset"
  type        = list(string)
  default     = []
}

variable "marts_readers" {
  description = "List of IAM members with read access to the marts dataset"
  type        = list(string)
  default     = []
}

# --- Dataflow ----------------------------------------------------------------

variable "dataflow_service_account_email" {
  description = "Service account email for Dataflow jobs"
  type        = string
}

variable "dataflow_temp_bucket" {
  description = "GCS bucket name for Dataflow temporary files"
  type        = string
}

variable "dataflow_staging_bucket" {
  description = "GCS bucket name for Dataflow staging files"
  type        = string
}

# --- Cloud Composer ----------------------------------------------------------

variable "composer_service_account_email" {
  description = "Service account email for Cloud Composer environment"
  type        = string
}

variable "composer_image_version" {
  description = "Cloud Composer image version. Use Composer 2 images."
  type        = string
  default     = "composer-2.9.7-airflow-2.9.3"
}

variable "composer_scheduler_cpu" {
  description = "CPU allocation for Airflow scheduler"
  type        = number
  default     = 2
}

variable "composer_scheduler_memory" {
  description = "Memory allocation (GB) for Airflow scheduler"
  type        = number
  default     = 4
}

variable "composer_worker_cpu" {
  description = "CPU allocation per Airflow worker"
  type        = number
  default     = 2
}

variable "composer_worker_memory" {
  description = "Memory allocation (GB) per Airflow worker"
  type        = number
  default     = 4
}

variable "composer_worker_min_count" {
  description = "Minimum number of Airflow workers"
  type        = number
  default     = 2
}

variable "composer_worker_max_count" {
  description = "Maximum number of Airflow workers (auto-scaling upper bound)"
  type        = number
  default     = 6
}
