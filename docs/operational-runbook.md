# Operational Runbook

## Overview

This runbook covers monitoring, alerting, incident response, and operational procedures for the reference data platform.

---

## Monitoring

### Key Dashboards

| Dashboard | What It Shows | Check Frequency |
|-----------|--------------|-----------------|
| Composer DAG Overview | DAG run status, execution times, SLA compliance | Every 4 hours |
| BigQuery Slot Utilization | Query performance, slot usage, reservation efficiency | Daily |
| Dataflow Pipeline Health | Active jobs, throughput, error rates, backlog | Every hour |
| Data Quality (dbt) | Test pass/fail rates, model freshness | After each dbt run |
| Cost Monitoring | BigQuery, Dataflow, Composer, GCS costs by label | Weekly |

### Critical Metrics

| Metric | Warning Threshold | Critical Threshold | Action |
|--------|-------------------|-------------------|--------|
| DAG failure rate | >5% of runs | >10% of runs | Investigate task logs |
| dbt test failures | Any warning-severity | Any error-severity | Pause downstream, investigate |
| Dataflow backlog | >10 min of unprocessed data | >30 min | Scale workers, check source |
| BigQuery query latency (p95) | >30 seconds | >120 seconds | Check slot utilization |
| Dead-letter queue depth | >100 records/hour | >1000 records/hour | Check source data quality |
| GCS bucket size growth | >20% above forecast | >50% above forecast | Review retention policies |

---

## Alerting

### Alert Routing

| Severity | Channel | Response Time |
|----------|---------|---------------|
| Critical | PagerDuty + Slack #data-platform-incidents | 15 minutes |
| Warning | Slack #data-platform-alerts | 4 hours |
| Info | Slack #data-platform-monitoring | Next business day |

### Common Alerts and Response

#### DAG Failure
1. Check Airflow UI → DAG Runs → identify failed task
2. Review task logs for error details
3. Common causes:
   - BigQuery quota exceeded → request quota increase or optimize query
   - dbt compilation error → check recent model changes
   - Upstream data not available → check source system status
4. Clear the failed task and trigger retry (if transient)
5. If systemic, pause the DAG and escalate

#### dbt Test Failure
1. Check dbt run logs for specific test failure
2. Assess severity:
   - **Uniqueness/not-null on hub keys:** Critical — potential data corruption. Pause downstream.
   - **Referential integrity:** High — investigate orphan records.
   - **Accepted values/custom:** Medium — investigate but downstream may continue.
3. Query the failing model directly to understand the scope of the issue
4. Fix the root cause (data quality, model logic, source system change)
5. Re-run affected models

#### Dataflow Pipeline Stuck
1. Check Dataflow UI for job status and error messages
2. Common causes:
   - Schema change in source data → update pipeline schema mapping
   - Pub/Sub message backlog → check subscription health
   - Worker OOM → increase worker machine type
3. If job is stuck, drain the current job and launch a replacement
4. Check dead-letter queue for dropped records

---

## Incident Response

### Severity Classification

| Severity | Definition | Response SLA |
|----------|-----------|--------------|
| P1 | Data pipeline completely stopped, downstream reporting affected | 15 min |
| P2 | Data quality issue affecting production reports | 1 hour |
| P3 | Performance degradation or non-critical pipeline failure | 4 hours |
| P4 | Minor issue, no immediate business impact | Next business day |

### Response Procedure

1. **Acknowledge** the alert within the response SLA
2. **Assess** the impact — which downstream systems/reports are affected?
3. **Communicate** status to stakeholders (Slack channel, email for P1/P2)
4. **Investigate** root cause using logs, metrics, and query history
5. **Remediate** — fix the issue and re-process affected data if needed
6. **Verify** — confirm data quality post-remediation using dbt tests
7. **Document** — update incident log with root cause, timeline, and prevention measures

### Post-Incident Review
For P1 and P2 incidents, conduct a blameless post-incident review within 5 business days:
- Timeline of events
- Root cause analysis
- What went well in the response
- What could be improved
- Action items with owners and deadlines

---

## Scaling Procedures

### BigQuery
- **On-demand → Flat-rate:** If monthly on-demand costs consistently exceed flat-rate pricing, switch to slot reservations.
- **Slot scaling:** Use autoscaling reservations for burst workloads. Set baseline slots for predictable workloads.
- **Partitioning:** Ensure large tables are partitioned by date. Add clustering on frequently filtered columns.

### Dataflow
- **Autoscaling:** Dataflow autoscaling is enabled by default. Set `maxNumWorkers` to prevent runaway scaling.
- **Machine type:** For memory-intensive transforms (e.g., large joins), increase worker machine type rather than worker count.
- **Streaming vs. batch:** If streaming latency is not required, switch to batch mode for cost efficiency.

### Cloud Composer
- **Worker scaling:** Adjust `worker_min_count` and `worker_max_count` in Terraform based on DAG parallelism requirements.
- **Scheduler:** In production, use 2 schedulers for HA. Increase scheduler CPU/memory if parse times are slow.
- **Environment size:** Scale from MEDIUM to LARGE when managing >100 DAGs.

---

## Backup and Recovery

### BigQuery
- **Snapshots:** BigQuery supports table snapshots for point-in-time recovery. Configure daily snapshots for vault and marts datasets.
- **Time travel:** BigQuery retains 7 days of change history. Any table can be queried at a point in time within this window.
- **Cross-region:** For disaster recovery, configure BigQuery dataset replication to a secondary region.

### Cloud Composer
- **DAG versioning:** All DAGs are in Git — recovery is a redeployment from the repository.
- **Airflow metadata:** Composer stores metadata in Cloud SQL. Automated backups are enabled by default.
- **Environment recreation:** Composer environments can be recreated from Terraform in ~30 minutes. Variable and connection data should be stored in Secret Manager.

### GCS
- **Object versioning:** Enabled on staging and dead-letter buckets for accidental deletion recovery.
- **Lifecycle policies:** Configured to auto-delete old objects based on retention requirements.

---

## Routine Maintenance

| Task | Frequency | Owner |
|------|-----------|-------|
| Review and rotate KMS keys | Automated (90-day rotation) | Platform team |
| Review IAM access | Monthly | Platform team + Security |
| Review BigQuery costs and optimize | Weekly | Platform team |
| Update Composer image version | Quarterly (or on security patch) | Platform team |
| Review dead-letter queue records | Daily | Data engineering |
| dbt package updates | Monthly | Data engineering |
| Terraform provider updates | Quarterly | Platform team |
| Disaster recovery drill | Semi-annually | Platform team + SRE |
