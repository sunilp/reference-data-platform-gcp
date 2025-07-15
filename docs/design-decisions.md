# Architecture Decision Records

This document captures the key architectural decisions made for this reference data platform, including context, options considered, rationale, and known trade-offs.

---

## ADR-001: Data Vault 2.0 over Kimball Dimensional Modeling

**Status:** Accepted
**Date:** 2022-08-15

### Context
We need a data modeling methodology for the enterprise data warehouse that serves both analytical workloads and regulatory reporting. The platform must support full data lineage, historical reconstruction, and parallel development across multiple source system integration streams.

### Options Considered
1. **Kimball Dimensional Modeling** — Star/snowflake schemas optimized for query performance
2. **Data Vault 2.0** — Hub, Link, Satellite pattern optimized for auditability and agility
3. **One Big Table (OBT)** — Fully denormalized tables per domain

### Decision
**Data Vault 2.0** for the core warehouse (raw vault and business vault layers), with Kimball-style star schemas in the marts layer for business consumption.

### Rationale
- **Regulatory auditability:** Data Vault stores every version of every record with load timestamps and record sources. This directly addresses BCBS 239 requirements for data lineage and historical reconstruction.
- **Parallel loading:** Hubs, links, and satellites can be loaded independently, enabling parallel development across teams and source systems.
- **Schema evolution:** New sources can be integrated without restructuring existing models — new satellites are added to existing hubs.
- **Separation of concerns:** Business rules are applied only in the business vault and marts layers, keeping the raw vault as a faithful record of source system data.

### Trade-offs
- **Query complexity:** Querying the raw vault directly requires multiple joins (hub → satellite, hub → link → hub). This is mitigated by the marts layer.
- **Learning curve:** Data Vault concepts (hubs, links, satellites, hashdiff) are less intuitive than star schemas. Team training is required.
- **Storage:** Full historization uses more storage than slowly-changing dimension approaches. BigQuery's columnar storage and compression mitigate this.

---

## ADR-002: Cloud Composer over Cloud Functions for Orchestration

**Status:** Accepted
**Date:** 2022-09-01

### Context
The data platform requires orchestration of multi-step data pipelines with dependencies, retries, SLA monitoring, and alerting. Pipelines include: Dataflow ingestion → dbt staging → dbt vault → dbt marts → downstream notifications.

### Options Considered
1. **Cloud Composer (managed Airflow)** — DAG-based orchestration
2. **Cloud Functions + Cloud Scheduler** — Serverless event-driven orchestration
3. **Cloud Workflows** — GCP-native workflow orchestration
4. **Prefect / Dagster** — Modern orchestration tools (self-hosted)

### Decision
**Cloud Composer 2** (managed Apache Airflow).

### Rationale
- **Dependency management:** Airflow DAGs natively express task dependencies, ensuring correct execution order across complex multi-step pipelines.
- **Observability:** Built-in UI for DAG monitoring, task logs, run history, SLA tracking, and alerting.
- **dbt integration:** dbt DAGs can be generated and executed within Airflow using established operators and packages.
- **Operational maturity:** Airflow is widely adopted in financial services, with established patterns for production operation.
- **Managed service:** Composer 2 handles Airflow infrastructure (GKE, Cloud SQL, Redis), reducing operational burden.

### Trade-offs
- **Cost:** Composer is more expensive than serverless alternatives for simple workloads. At enterprise scale, the operational efficiency justifies the cost.
- **Cold start:** Composer environments take 20-30 minutes to create. This is an infrastructure concern, not a runtime concern.
- **Complexity:** Airflow configuration has a learning curve. The managed service reduces but does not eliminate operational complexity.

### Why Not Cloud Functions?
Cloud Functions are appropriate for simple, event-driven tasks but lack native dependency management, DAG visualization, SLA monitoring, and the retry/backfill capabilities needed for complex data pipelines.

---

## ADR-003: BigQuery as the Analytical Data Warehouse

**Status:** Accepted
**Date:** 2022-07-20

### Context
The platform needs a scalable analytical data warehouse that supports the full data lifecycle (raw → vault → marts) with enterprise security controls.

### Options Considered
1. **BigQuery** — GCP-native serverless data warehouse
2. **Snowflake** — Multi-cloud data warehouse
3. **Apache Spark on Dataproc** — Open-source distributed processing

### Decision
**BigQuery**.

### Rationale
- **GCP-native:** Tight integration with Dataflow, Composer, IAM, VPC Service Controls, and Cloud KMS. No data egress costs within GCP.
- **Serverless:** No cluster management, auto-scaling, pay-per-query pricing for ad-hoc workloads.
- **Security:** Column-level security, row-level access policies, customer-managed encryption keys (CMEK), and VPC Service Controls for data exfiltration prevention.
- **dbt support:** First-class dbt-bigquery adapter with incremental model support, merge operations, and BigQuery-specific optimizations.
- **Cost model:** Flat-rate pricing available for predictable workloads, on-demand for development and ad-hoc queries.

### Trade-offs
- **Vendor lock-in:** BigQuery SQL has extensions that are not portable to other warehouses. Mitigation: dbt abstracts most platform-specific SQL.
- **Streaming costs:** Streaming inserts are priced separately and can be expensive at high volume. Mitigation: Batch loading via Dataflow for most workloads.

---

## ADR-004: Network Security Model

**Status:** Accepted
**Date:** 2022-10-01

### Context
Financial services regulations require strong network-level controls to prevent unauthorized data access and exfiltration.

### Decision
**VPC Service Controls** perimeter around all data platform resources, with **private IP only** for Composer and Dataflow.

### Key Controls
1. **VPC Service Controls:** Create a service perimeter that restricts BigQuery, GCS, Dataflow, and Composer to authorized VPC networks only. This prevents data exfiltration even if credentials are compromised.
2. **Private IP:** Composer and Dataflow workers use private IP addresses only — no public internet access.
3. **Authorized networks:** BigQuery access restricted to approved IP ranges and VPN connections.
4. **Firewall rules:** Egress restricted to required Google APIs only (via Private Google Access).

### Trade-offs
- **Development friction:** Developers cannot access BigQuery from personal devices without VPN. Mitigated by providing development environments within the VPC.
- **Complexity:** VPC-SC configuration is complex and errors can block legitimate access. Mitigated by thorough testing in non-prod environments before applying to production.

---

## ADR-005: Customer-Managed Encryption Keys (CMEK)

**Status:** Accepted
**Date:** 2022-08-01

### Context
Regulatory requirements mandate that the organization maintains custody of encryption keys used to protect sensitive data. GCP's default encryption (Google-managed keys) does not satisfy this requirement.

### Decision
**Cloud KMS with customer-managed keys** for all data platform resources (BigQuery datasets, GCS buckets, Composer environment, Dataflow temp storage).

### Implementation
- Single KMS keyring per environment (dev/staging/prod)
- Separate keys per service (BigQuery, GCS, Composer) for blast radius containment
- Key rotation: automatic rotation every 90 days
- Key access: restricted to service accounts only — no human key access
- Key destruction: disabled (regulatory requirement to maintain decryption capability)

### Trade-offs
- **Operational overhead:** KMS key management adds operational complexity. Key permissions must be managed alongside resource permissions.
- **Cost:** CMEK adds a small per-operation cost for encryption/decryption. Negligible at expected volumes.
- **Availability dependency:** If the KMS key becomes unavailable (e.g., permissions revoked), all encrypted data becomes inaccessible. Mitigated by key access controls and monitoring.

