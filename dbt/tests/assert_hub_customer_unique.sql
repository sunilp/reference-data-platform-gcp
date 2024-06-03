-- Test: assert_hub_customer_unique
-- Validates that each customer business key appears exactly once in the hub.
-- A duplicate would indicate a hash collision or a loading defect.

select
    customer_id,
    count(*) as occurrences
from {{ ref('hub_customer') }}
group by customer_id
having count(*) > 1
