-- Staging model: stg_transactions
-- Source: core banking transaction feed (raw.transactions)
-- Purpose: Cleanse, type-cast, and prepare data for Data Vault loading.
--
-- This model:
--   1. Applies consistent data types
--   2. Generates hash keys for hub and link loading
--   3. Generates hashdiff for satellite change detection
--   4. Adds load metadata (record_source, load_datetime)

with source as (
    select *
    from {{ source('raw', 'transactions') }}
),

cleaned as (
    select
        -- Business keys
        cast(transaction_id as string)   as transaction_id,
        cast(customer_id as string)      as customer_id,
        cast(account_number as string)   as account_number,

        -- Descriptive attributes
        cast(transaction_amount as numeric)  as transaction_amount,
        upper(trim(transaction_currency))    as transaction_currency,
        upper(trim(transaction_type))        as transaction_type,
        cast(transaction_timestamp as timestamp) as transaction_timestamp,
        trim(merchant_name)                  as merchant_name,
        trim(merchant_category)              as merchant_category,
        upper(trim(transaction_status))      as transaction_status,
        trim(channel)                        as channel,

        -- Hash keys for Data Vault
        {{ dbt_utils.generate_surrogate_key(['customer_id']) }}
            as hk_customer,
        {{ dbt_utils.generate_surrogate_key(['account_number']) }}
            as hk_account,
        {{ dbt_utils.generate_surrogate_key(['customer_id', 'account_number']) }}
            as hk_customer_account,
        {{ dbt_utils.generate_surrogate_key(['transaction_id']) }}
            as hk_transaction,

        -- Hashdiff for satellite change detection
        {{ dbt_utils.generate_surrogate_key([
            'transaction_amount',
            'transaction_currency',
            'transaction_type',
            'merchant_name',
            'merchant_category',
            'transaction_status',
            'channel'
        ]) }} as hashdiff_transaction,

        -- Load metadata
        '{{ var("record_source", "CORE_BANKING") }}' as record_source,
        {{ var("load_datetime", "current_timestamp()") }} as load_datetime

    from source
    where transaction_id is not null
)

select * from cleaned
