# Reference Data Platform — GCP

**A reference architecture for building a compliant enterprise data platform on Google Cloud**

---

## Problem Statement

Regulated financial institutions need data platforms that serve two masters: **business agility** (fast access to trusted data for analytics, reporting, and AI) and **regulatory compliance** (full lineage, auditability, retention, and access controls).

Most data platform implementations optimize for one at the expense of the other. This reference architecture demonstrates how to achieve both by combining:
- **BigQuery** for scalable analytical compute
- **Dataflow** for streaming and batch data ingestion
- **Cloud Composer** for orchestration
- **dbt** for transformation with Data Vault 2.0 modeling
- **Terraform** for infrastructure-as-code with security controls built in

The architecture is designed for Tier-1 banking requirements — BCBS 239 compliant data aggregation, DORA operational resilience, and full audit traceability.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Source Systems                                │
│  Core Banking │ Card Processing │ CRM │ Market Data │ External Feeds│
└──────┬────────┴───────┬─────────┴──┬──┴──────┬──────┴───────┬───────┘
       │                │            │         │              │
       ▼                ▼            ▼         ▼              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     Ingestion Layer (Dataflow)                      │
│  Streaming (Pub/Sub → Dataflow) │ Batch (GCS → Dataflow)           │
│  Schema validation │ Data quality checks │ Encryption │ Audit log   │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     BigQuery Data Warehouse                         │
│                                                                     │
│  ┌──────────┐  ┌──────────────┐  ┌───────────────┐  ┌───────────┐ │
│  │   Raw    │→ │   Staging    │→ │   Raw Vault   │→ │   Marts   │ │
│  │  (land)  │  │  (cleanse)   │  │ (Data Vault)  │  │ (consume) │ │
│  └──────────┘  └──────────────┘  └───────────────┘  └───────────┘ │
│                                                                     │
│  Column-level security │ Row-level access │ Encryption (CMEK)       │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  Orchestration (Cloud Composer / Airflow)            │
│  DAG scheduling │ Dependency management │ SLA monitoring │ Alerting │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  Transformation (dbt + Data Vault 2.0)              │
│  Staging → Hubs, Links, Satellites → Business Vault → Marts        │
│  Full historization │ Lineage tracking │ Automated testing          │
└─────────────────────────────────────────────────────────────────────┘
```

Architecture diagrams (draw.io/Excalidraw format) are available in the `architecture/` directory.

## Key Design Decisions

This architecture makes several opinionated choices. Each is documented with rationale and trade-offs in [docs/design-decisions.md](docs/design-decisions.md).

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Modeling methodology | Data Vault 2.0 | Full historization, parallel loading, regulatory auditability |
| Orchestration | Cloud Composer (Airflow) | Mature dependency management, DAG-as-code, operational tooling |
| Transformation | dbt | SQL-based, version-controlled, testable, strong community |
| Infrastructure | Terraform | Reproducible, reviewable, drift-detectable |
| Encryption | Customer-managed keys (CMEK) | Regulatory requirement for key custody |
| Network | VPC Service Controls | Data exfiltration prevention perimeter |

## Regulatory Mapping

| Requirement | Regulation | How This Architecture Addresses It |
|-------------|-----------|-----------------------------------|
| Data lineage and traceability | BCBS 239 | Data Vault 2.0 tracks record source and load timestamps at every layer. dbt provides column-level lineage. |
| Data quality controls | BCBS 239 | dbt tests at every layer. Dataflow validates schemas on ingestion. |
| Timely risk data aggregation | BCBS 239 | Streaming ingestion via Dataflow + Pub/Sub enables near-real-time aggregation. |
| ICT risk management | DORA | Terraform-managed infrastructure, monitoring, alerting, incident response runbook. |
| Operational resilience testing | DORA | Infrastructure defined as code enables reproducible disaster recovery testing. |
| Technology risk management | MAS TRM | Access controls (IAM + column/row security), encryption (CMEK), audit logging, change management via Terraform. |

## Repository Structure

```
reference-data-platform-gcp/
├── architecture/              # Architecture diagrams
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # Core module composition
│   ├── variables.tf          # Configuration variables
│   ├── outputs.tf            # Infrastructure outputs
│   └── modules/
│       ├── bigquery/         # Datasets, tables, IAM, encryption
│       ├── dataflow/         # Ingestion pipeline infrastructure
│       └── composer/         # Airflow environment setup
├── dbt/                      # Data transformation
│   ├── dbt_project.yml
│   └── models/
│       ├── staging/          # Raw → cleansed staging
│       ├── vault/            # Data Vault 2.0 (hubs, links, satellites)
│       └── marts/            # Business-ready consumption views
├── docs/
│   ├── design-decisions.md   # Architecture Decision Records
│   ├── compliance-patterns.md # Regulatory compliance patterns
│   └── operational-runbook.md # Operations and incident response
└── LICENSE
```

## Getting Started

### Prerequisites
- Google Cloud SDK (`gcloud`) configured with appropriate project access
- Terraform >= 1.5
- dbt-core >= 1.7 with dbt-bigquery adapter
- Python >= 3.10

### Deploy Infrastructure
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars  # Edit with your project details
terraform init
terraform plan
terraform apply
```

### Run Transformations
```bash
cd dbt
cp profiles.yml.example profiles.yml  # Edit with your BigQuery connection
dbt deps
dbt seed        # Load reference data
dbt run         # Run all models
dbt test        # Run all tests
```

### Verify
- Check BigQuery console for dataset creation (raw, staging, vault, marts)
- Verify Cloud Composer DAGs are visible in Airflow UI
- Confirm Dataflow jobs are in a ready state

## Important Notes

This is a **reference architecture**, not production-ready code. It demonstrates:
- How to structure a compliant data platform on GCP
- Design decisions and trade-offs at the architectural level
- Documentation standards for regulated environments

Production deployment would require additional hardening: network security reviews, penetration testing, load testing, operational readiness assessment, and regulatory approval.

## License

Apache 2.0 — see [LICENSE](LICENSE).

