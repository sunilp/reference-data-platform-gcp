# Compliance Patterns

How this reference architecture addresses key regulatory requirements for data platforms in financial services.

---

## BCBS 239 — Risk Data Aggregation and Reporting

The Basel Committee's Principles for Effective Risk Data Aggregation (BCBS 239) requires banks to have strong capabilities for aggregating risk data accurately, completely, and in a timely manner.

### Principle 3: Accuracy and Integrity

**Requirement:** Data should be aggregated on a largely automated basis to minimize the probability of errors.

**How this architecture addresses it:**
- **Automated ingestion:** Dataflow pipelines validate schemas and data types on ingestion. Malformed records are routed to the dead-letter queue — they never silently enter the warehouse.
- **dbt tests:** Every model layer (staging, vault, marts) has automated tests for null checks, uniqueness, referential integrity, and accepted values.
- **Data Vault immutability:** Raw vault data is insert-only. Source data is never overwritten, providing an immutable record for reconciliation.

### Principle 4: Completeness

**Requirement:** A bank should be able to capture and aggregate all material risk data across the group.

**How this architecture addresses it:**
- **Centralized warehouse:** All source systems feed into a single BigQuery warehouse, eliminating data silos.
- **Record source tracking:** Every record in the Data Vault carries a `record_source` field identifying its origin system.
- **Completeness testing:** dbt tests validate that expected record volumes are met and that no source systems are missing from daily loads.

### Principle 5: Timeliness

**Requirement:** Banks should be able to generate aggregate risk data in a timely manner to meet reporting frequency requirements.

**How this architecture addresses it:**
- **Streaming ingestion:** Dataflow supports streaming ingestion from Pub/Sub for near-real-time data availability.
- **Incremental loading:** Data Vault models use incremental materialization — only new/changed records are processed, enabling fast refresh cycles.
- **SLA monitoring:** Cloud Composer tracks DAG execution times and alerts on SLA misses.

### Principle 6: Adaptability

**Requirement:** Risk data aggregation capabilities should be adaptable to changes in business requirements and regulation.

**How this architecture addresses it:**
- **Data Vault agility:** New source systems are integrated by adding new satellites to existing hubs, without restructuring the existing model.
- **Mart flexibility:** Business-facing marts can be added, modified, or replaced independently of the raw vault.
- **Infrastructure as code:** Terraform enables rapid provisioning of new datasets, pipelines, and access controls.

---

## DORA — Digital Operational Resilience Act

DORA requires financial entities to ensure ICT systems supporting critical functions are resilient, recoverable, and continuously monitored.

### ICT Risk Management (Article 6)

**How this architecture addresses it:**
- **Infrastructure as code:** All infrastructure is defined in Terraform, enabling version control, peer review, and reproducible deployments.
- **Private networking:** VPC Service Controls and private IP configurations prevent unauthorized access.
- **Encryption:** CMEK provides customer-managed encryption at rest for all data assets.
- **Access controls:** IAM bindings are defined per dataset layer with least-privilege principles.

### ICT Incident Management (Article 17)

**How this architecture addresses it:**
- **Monitoring and alerting:** Cloud Composer provides DAG-level monitoring. BigQuery provides query-level audit logs. Dataflow provides pipeline metrics.
- **Operational runbook:** Documented incident response procedures in [operational-runbook.md](operational-runbook.md).
- **Dead-letter queues:** Failed ingestion records are captured for analysis and replay, not silently dropped.

### Testing (Article 24-27)

**How this architecture addresses it:**
- **Reproducible environments:** Terraform enables creation of identical test environments for resilience testing.
- **Data quality testing:** dbt tests provide continuous validation of data integrity.
- **Disaster recovery:** GCS and BigQuery support cross-region replication for critical datasets.

---

## Audit Logging and Lineage

### What Is Logged

| Layer | What Is Captured |
|-------|-----------------|
| Ingestion (Dataflow) | Record counts, schema validation results, dead-letter records, processing timestamps |
| Orchestration (Composer) | DAG run history, task execution times, failures, retries, SLA status |
| Warehouse (BigQuery) | All queries (DATA_READ), all modifications (DATA_WRITE), IAM changes (ADMIN_ACTIVITY) |
| Transformation (dbt) | Model execution logs, test results, run metadata |

### Data Lineage

- **Record source:** Every Data Vault record tracks which source system it originated from.
- **Load datetime:** Every record tracks when it was loaded, enabling point-in-time reconstruction.
- **dbt lineage:** dbt generates a full DAG showing column-level lineage from source to mart.
- **BigQuery lineage:** BigQuery INFORMATION_SCHEMA provides query-level lineage for all transformations.

### Retention

- Audit logs: exported to a dedicated audit project and retained for 7 years.
- BigQuery query logs: retained for 7 years via log sink to Cloud Storage.
- dbt run artifacts: retained in GCS for 3 years.

---

## Data Retention and Right-to-Delete

### Retention Policies

| Dataset | Retention Period | Rationale |
|---------|-----------------|-----------|
| Raw | 7 years | Regulatory minimum for transaction records |
| Staging | 90 days | Working layer — no long-term retention needed |
| Vault | Indefinite (with archival) | Full history required for regulatory reconstruction |
| Marts | Current + 1 year | Business consumption — refreshed from vault |

### Right-to-Delete (GDPR Article 17)

Data Vault's insert-only model creates tension with right-to-delete requirements:
- **Approach:** Logical deletion via a deletion satellite. A `sat_customer_deletion` model marks deleted customers without physically removing records from hubs or other satellites.
- **Mart filtering:** Mart models filter out logically deleted customers, ensuring they do not appear in business-facing views.
- **Physical deletion:** For jurisdictions requiring physical deletion, a batch process can purge records from raw and vault layers with full audit logging of the deletion event.

---

## Column-Level Security

BigQuery supports column-level security via policy tags:

- **Restricted columns** (e.g., customer name, account number): Tagged with a "restricted" policy. Only authorized roles can access.
- **Internal columns** (e.g., transaction amounts, aggregates): Tagged with "internal" policy. Broader access for analysts.
- **Public columns** (e.g., record counts, aggregated metrics): No policy tag required.

Implementation:
1. Define taxonomy and policy tags in Data Catalog
2. Apply policy tags to BigQuery column schemas
3. Grant fine-grained reader access to specific IAM groups
4. dbt models inherit column policies from their source tables
