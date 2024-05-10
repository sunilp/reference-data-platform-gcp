-- Mart: dim_customer_accounts
-- Purpose: Business-ready view combining customer and account data
--
-- This model flattens the Data Vault structure into a consumption-ready
-- dimension. Business users and BI tools query this layer — they never
-- need to understand hubs, links, or satellites.

with customers as (
    select
        hk_customer,
        customer_id,
        load_datetime as first_seen_date
    from {{ ref('hub_customer') }}
),

accounts as (
    select
        hk_account,
        account_number,
        load_datetime as account_first_seen_date
    from {{ ref('hub_account') }}
),

customer_accounts as (
    select
        hk_customer_account,
        hk_customer,
        hk_account,
        load_datetime as relationship_start_date
    from {{ ref('link_customer_account') }}
),

latest_balance as (
    select
        hk_account,
        transaction_amount as latest_transaction_amount,
        transaction_currency,
        transaction_status as latest_status,
        load_datetime as balance_as_of
    from {{ ref('sat_account_balance') }}
    qualify row_number() over (
        partition by hk_account
        order by load_datetime desc
    ) = 1
)

select
    c.customer_id,
    a.account_number,
    c.first_seen_date,
    a.account_first_seen_date,
    ca.relationship_start_date,
    lb.latest_transaction_amount,
    lb.transaction_currency,
    lb.latest_status,
    lb.balance_as_of

from customer_accounts ca
inner join customers c on ca.hk_customer = c.hk_customer
inner join accounts a on ca.hk_account = a.hk_account
left join latest_balance lb on a.hk_account = lb.hk_account
