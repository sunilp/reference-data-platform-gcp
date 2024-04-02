-- Satellite: sat_customer_details
-- Parent hub: hub_customer
-- Tracks: Customer descriptive attributes over time
--
-- Satellites store the descriptive context for business entities.
-- A new record is inserted only when attributes change (detected via hashdiff).
-- This provides full history — you can reconstruct the state of any entity
-- at any point in time, which is critical for regulatory compliance.

{{
    config(
        materialized='incremental',
        unique_key='hk_customer'
    )
}}

with staged as (
    select
        hk_customer,
        -- In a full implementation, these would come from a customer master feed
        -- For this reference, we derive what we can from transaction data
        customer_id,
        record_source,
        load_datetime,
        {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as hashdiff
    from {{ ref('stg_transactions') }}
    where hk_customer is not null
),

{% if is_incremental() %}
latest as (
    select
        hk_customer,
        hashdiff
    from {{ this }}
    qualify row_number() over (
        partition by hk_customer
        order by load_datetime desc
    ) = 1
),
{% endif %}

new_records as (
    select
        staged.hk_customer,
        staged.customer_id,
        staged.hashdiff,
        staged.record_source,
        staged.load_datetime
    from staged
    {% if is_incremental() %}
    left join latest
        on staged.hk_customer = latest.hk_customer
    where latest.hk_customer is null
       or staged.hashdiff != latest.hashdiff
    {% endif %}
    qualify row_number() over (
        partition by staged.hk_customer, staged.hashdiff
        order by staged.load_datetime asc
    ) = 1
)

select * from new_records
