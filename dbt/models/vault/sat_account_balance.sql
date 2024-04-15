-- Satellite: sat_account_balance
-- Parent hub: hub_account
-- Tracks: Account balance and status over time

{{
    config(
        materialized='incremental',
        unique_key='hk_account'
    )
}}

with staged as (
    select
        hk_account,
        account_number,
        transaction_amount,
        transaction_currency,
        transaction_status,
        record_source,
        load_datetime,
        {{ dbt_utils.generate_surrogate_key([
            'account_number',
            'transaction_amount',
            'transaction_currency',
            'transaction_status'
        ]) }} as hashdiff
    from {{ ref('stg_transactions') }}
    where hk_account is not null
),

{% if is_incremental() %}
latest as (
    select
        hk_account,
        hashdiff
    from {{ this }}
    qualify row_number() over (
        partition by hk_account
        order by load_datetime desc
    ) = 1
),
{% endif %}

new_records as (
    select
        staged.hk_account,
        staged.account_number,
        staged.transaction_amount,
        staged.transaction_currency,
        staged.transaction_status,
        staged.hashdiff,
        staged.record_source,
        staged.load_datetime
    from staged
    {% if is_incremental() %}
    left join latest
        on staged.hk_account = latest.hk_account
    where latest.hk_account is null
       or staged.hashdiff != latest.hashdiff
    {% endif %}
    qualify row_number() over (
        partition by staged.hk_account, staged.hashdiff
        order by staged.load_datetime asc
    ) = 1
)

select * from new_records
