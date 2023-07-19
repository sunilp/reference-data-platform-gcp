# =============================================================================
# Outputs — Reference Data Platform
# =============================================================================

# --- BigQuery ----------------------------------------------------------------

output "bigquery_raw_dataset_id" {
  description = "BigQuery raw (landing) dataset ID"
  value       = module.bigquery.raw_dataset_id
}

output "bigquery_staging_dataset_id" {
  description = "BigQuery staging dataset ID"
  value       = module.bigquery.staging_dataset_id
}

output "bigquery_vault_dataset_id" {
  description = "BigQuery vault dataset ID"
  value       = module.bigquery.vault_dataset_id
}

output "bigquery_marts_dataset_id" {
  description = "BigQuery marts dataset ID"
  value       = module.bigquery.marts_dataset_id
}

# --- Cloud Composer ----------------------------------------------------------

output "composer_environment_id" {
  description = "Cloud Composer environment resource ID"
  value       = module.composer.environment_id
}

output "composer_airflow_uri" {
  description = "Cloud Composer Airflow web UI URL"
  value       = module.composer.airflow_uri
}

output "composer_dag_gcs_prefix" {
  description = "GCS path prefix for uploading Airflow DAGs"
  value       = module.composer.dag_gcs_prefix
}

# --- Dataflow ----------------------------------------------------------------

output "dataflow_temp_bucket" {
  description = "GCS bucket for Dataflow temporary files"
  value       = module.dataflow.temp_bucket_name
}

output "dataflow_staging_bucket" {
  description = "GCS bucket for Dataflow staging files"
  value       = module.dataflow.staging_bucket_name
}
