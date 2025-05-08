-- Hub: hub_account
-- Business key: account_number
-- Grain: One record per unique account

{{
    config(
        materialized='incremental',
        unique_key='hk_account'
    )
}}

with staged as (
    select distinct
        hk_account,
        account_number,
        record_source,
        load_datetime
    from {{ ref('stg_transactions') }}
    where hk_account is not null
),

{% if is_incremental() %}
existing as (
    select hk_account from {{ this }}
),
{% endif %}

new_records as (
    select
        hk_account,
        account_number,
        record_source,
        min(load_datetime) as load_datetime
    from staged
    {% if is_incremental() %}
    where hk_account not in (select hk_account from existing)
    {% endif %}
    group by hk_account, account_number, record_source
)

select * from new_records

