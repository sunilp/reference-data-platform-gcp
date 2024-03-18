-- Link: link_customer_account
-- Relationship: Customer ↔ Account
-- Grain: One record per unique customer-account combination
--
-- Links capture relationships between business entities.
-- Like hubs, they are insert-only and provide an immutable record
-- of all relationships that have ever existed.

{{
    config(
        materialized='incremental',
        unique_key='hk_customer_account'
    )
}}

with staged as (
    select distinct
        hk_customer_account,
        hk_customer,
        hk_account,
        record_source,
        load_datetime
    from {{ ref('stg_transactions') }}
    where hk_customer_account is not null
),

{% if is_incremental() %}
existing as (
    select hk_customer_account from {{ this }}
),
{% endif %}

new_records as (
    select
        hk_customer_account,
        hk_customer,
        hk_account,
        record_source,
        min(load_datetime) as load_datetime
    from staged
    {% if is_incremental() %}
    where hk_customer_account not in (select hk_customer_account from existing)
    {% endif %}
    group by hk_customer_account, hk_customer, hk_account, record_source
)

select * from new_records
