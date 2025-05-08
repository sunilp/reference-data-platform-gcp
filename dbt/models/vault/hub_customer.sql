-- Hub: hub_customer
-- Business key: customer_id
-- Grain: One record per unique customer
--
-- Hubs are insert-only. Once a business key is recorded, it is never
-- updated or deleted. This provides an immutable audit trail of all
-- entities that have ever existed in the system.

{{
    config(
        materialized='incremental',
        unique_key='hk_customer'
    )
}}

with staged as (
    select distinct
        hk_customer,
        customer_id,
        record_source,
        load_datetime
    from {{ ref('stg_transactions') }}
    where hk_customer is not null
),

{% if is_incremental() %}
existing as (
    select hk_customer from {{ this }}
),
{% endif %}

new_records as (
    select
        hk_customer,
        customer_id,
        record_source,
        min(load_datetime) as load_datetime
    from staged
    {% if is_incremental() %}
    where hk_customer not in (select hk_customer from existing)
    {% endif %}
    group by hk_customer, customer_id, record_source
)

select * from new_records

