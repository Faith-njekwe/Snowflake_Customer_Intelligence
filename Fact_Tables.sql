CREATE OR REPLACE TABLE MODELLED.FACT_SALES AS

-- WEB SALES
SELECT
    ORDER_NUMBER                            AS ORDER_NUMBER,
    BILL_CUSTOMER_SK                        AS CUSTOMER_KEY,
    ITEM_SK                                 AS PRODUCT_KEY,
    SOLD_DATE_SK                            AS DATE_KEY,
    PROMO_SK                                AS PROMOTION_KEY,
    NULL                                    AS STORE_KEY,
    'WEB'                                   AS SALES_CHANNEL,

    QUANTITY,
    LIST_PRICE,
    SALES_PRICE,
    WHOLESALE_COST,

    EXT_LIST_PRICE,
    EXT_SALES_PRICE,
    EXT_WHOLESALE_COST,

    EXT_DISCOUNT_AMT,
    COUPON_AMT,
    EXT_TAX,
    EXT_SHIP_COST,

    NET_PAID,
    NET_PAID_INC_TAX,
    NET_PAID_INC_SHIP,
    NET_PAID_INC_SHIP_TAX,
    NET_PROFIT,

    LOAD_DATE,
    BATCH_ID

FROM CURATED.WEB_SALES

UNION ALL

-- STORE SALES
SELECT
    SS_TICKET_NUMBER                        AS ORDER_NUMBER,
    SS_CUSTOMER_SK                          AS CUSTOMER_KEY,
    SS_ITEM_SK                              AS PRODUCT_KEY,
    SS_SOLD_DATE_SK                         AS DATE_KEY,
    SS_PROMO_SK                             AS PROMOTION_KEY,
    SS_STORE_SK                             AS STORE_KEY,
    'STORE'                                 AS SALES_CHANNEL,

    QUANTITY,
    LIST_PRICE,
    SALES_PRICE,
    WHOLESALE_COST,

    EXT_LIST_PRICE,
    EXT_SALES_PRICE,
    EXT_WHOLESALE_COST,

    EXT_DISCOUNT_AMT,
    COUPON_AMT,
    EXT_TAX,
    NULL,

    NET_PAID,
    NET_PAID_INC_TAX,
    NULL,
    NULL,
    NET_PROFIT,

    LOAD_DATE,
    BATCH_ID

FROM CURATED.STORE_SALES

UNION ALL

-- CATALOG SALES
SELECT
    CS_ORDER_NUMBER                         AS ORDER_NUMBER,
    CS_BILL_CUSTOMER_SK                     AS CUSTOMER_KEY,
    CS_ITEM_SK                              AS PRODUCT_KEY,
    CS_SOLD_DATE_SK                         AS DATE_KEY,
    CS_PROMO_SK                             AS PROMOTION_KEY,
    NULL                                    AS STORE_KEY,
    'CATALOG'                               AS SALES_CHANNEL,

    QUANTITY,
    LIST_PRICE,
    SALES_PRICE,
    WHOLESALE_COST,

    EXT_LIST_PRICE,
    EXT_SALES_PRICE,
    EXT_WHOLESALE_COST,

    EXT_DISCOUNT_AMT,
    COUPON_AMT,
    EXT_TAX,
    EXT_SHIP_COST,

    NET_PAID,
    NET_PAID_INC_TAX,
    NET_PAID_INC_SHIP,
    NET_PAID_INC_SHIP_TAX,
    NET_PROFIT,

    LOAD_DATE,
    BATCH_ID

FROM CURATED.CATALOG_SALES;

fact_sales;

select *
from curated.web_sales
Limit 10;

-- suggested columns
CREATE OR REPLACE TABLE MODELLED.FACT_RETURNS AS

-- WEB RETURNS
SELECT
    WR_ORDER_NUMBER                         AS RETURN_NUMBER,
    WR_REFUNDED_CUSTOMER_SK                 AS CUSTOMER_KEY,
    WR_ITEM_SK                              AS PRODUCT_KEY,
    WR_RETURNED_DATE_SK                     AS DATE_KEY,
    NULL                                    AS STORE_KEY,
    WR_REASON_SK                            AS REASON_KEY,
    'WEB'                                   AS RETURN_CHANNEL,

    RETURN_QUANTITY,
    RETURN_AMT,
    RETURN_TAX,
    RETURN_AMT_INC_TAX,
    FEE,
    RETURN_SHIP_COST,
    REFUNDED_CASH,
    REVERSED_CHARGE,
    ACCOUNT_CREDIT,
    NET_LOSS

FROM CURATED.WEB_RETURNS

UNION ALL

-- STORE RETURNS
SELECT
    SR_TICKET_NUMBER                        AS RETURN_NUMBER,
    SR_CUSTOMER_SK                          AS CUSTOMER_KEY,
    SR_ITEM_SK                              AS PRODUCT_KEY,
    SR_RETURNED_DATE_SK                     AS DATE_KEY,
    SR_STORE_SK                             AS STORE_KEY,
    SR_REASON_SK                            AS REASON_KEY,
    'STORE'                                 AS RETURN_CHANNEL,

    RETURN_QUANTITY,
    RETURN_AMT,
    RETURN_TAX,
    RETURN_AMT_INC_TAX,
    FEE,
    RETURN_SHIP_COST,
    REFUNDED_CASH,
    REVERSED_CHARGE,
    STORE_CREDIT,
    NET_LOSS

FROM CURATED.STORE_RETURNS

UNION ALL

-- CATALOG RETURNS
SELECT
    CR_ORDER_NUMBER                         AS RETURN_NUMBER,
    CR_REFUNDED_CUSTOMER_SK                 AS CUSTOMER_KEY,
    CR_ITEM_SK                              AS PRODUCT_KEY,
    CR_RETURNED_DATE_SK                     AS DATE_KEY,
    NULL                                    AS STORE_KEY,
    CR_REASON_SK                            AS REASON_KEY,
    'CATALOG'                               AS RETURN_CHANNEL,

    RETURN_QUANTITY,
    RETURN_AMOUNT                           AS RETURN_AMT,
    RETURN_TAX,
    RETURN_AMT_INC_TAX,
    FEE,
    RETURN_SHIP_COST,
    REFUNDED_CASH,
    REVERSED_CHARGE,
    STORE_CREDIT,
    NET_LOSS

FROM CURATED.CATALOG_RETURNS;

SELECT
    SALES_COUNT,
    RETURN_COUNT,
    ROUND(SALES_COUNT / NULLIF(RETURN_COUNT, 0), 2) AS SALES_TO_RETURN_RATIO
FROM
(
    SELECT COUNT(*) AS SALES_COUNT
    FROM MODELLED.FACT_SALES
) s
CROSS JOIN
(
    SELECT COUNT(*) AS RETURN_COUNT
    FROM MODELLED.FACT_RETURNS
) r;

select *
from fact_sales
limit 100;

desc table fact_sales;

desc table fact_returns;


select *
from fact_sales
limit 100;


-- fact customer activity

CREATE OR REPLACE TABLE MODELLED.FACT_CUSTOMER_ACTIVITY AS

WITH SALES_MONTHLY AS (
    SELECT
        F.CUSTOMER_KEY,
        D.D_YEAR,
        D.MONTH_NUMBER,

        COUNT(DISTINCT F.ORDER_NUMBER) AS ORDER_COUNT,
        SUM(F.NET_PAID) AS TOTAL_SPEND,
        SUM(F.NET_PROFIT) AS TOTAL_PROFIT,

        MAX(F.DATE_KEY) AS LAST_PURCHASE_DATE

    FROM MODELLED.FACT_SALES F
    JOIN MODELLED.DIM_DATE D
        ON F.DATE_KEY = D.D_DATE_SK

    GROUP BY
        F.CUSTOMER_KEY,
        D.D_YEAR,
        D.MONTH_NUMBER
),

RETURNS_MONTHLY AS (
    SELECT
        R.CUSTOMER_KEY,
        D.D_YEAR,
        D.MONTH_NUMBER,

        COUNT(*) AS RETURN_COUNT,
        SUM(R.RETURN_AMT) AS RETURN_AMOUNT

    FROM MODELLED.FACT_RETURNS R
    JOIN MODELLED.DIM_DATE D
        ON R.DATE_KEY = D.D_DATE_SK

    GROUP BY
        R.CUSTOMER_KEY,
        D.D_YEAR,
        D.MONTH_NUMBER
)

SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            S.CUSTOMER_KEY,
            S.D_YEAR,
            S.MONTH_NUMBER
    ) AS ACTIVITY_KEY,

    S.CUSTOMER_KEY,
    S.D_YEAR,
    S.MONTH_NUMBER,

    S.ORDER_COUNT,
    S.TOTAL_SPEND,
    S.TOTAL_PROFIT,

    COALESCE(R.RETURN_COUNT, 0) AS RETURN_COUNT,
    COALESCE(R.RETURN_AMOUNT, 0) AS RETURN_AMOUNT,

    S.TOTAL_SPEND - COALESCE(R.RETURN_AMOUNT, 0) AS NET_SPEND,

    S.LAST_PURCHASE_DATE

FROM SALES_MONTHLY S
LEFT JOIN RETURNS_MONTHLY R
    ON S.CUSTOMER_KEY = R.CUSTOMER_KEY
   AND S.D_YEAR = R.D_YEAR
   AND S.MONTH_NUMBER = R.MONTH_NUMBER;

select *
from fact_sales
limit 100;

select *
from dim_date;

select *
from fact_customer_activity;

select *
from fact_customer_activity
where customer_key = '7065064';

-- investigating negative profits
select *
from fact_sales
where net_profit < 0
limit 100;

-- Will leave out the promotion table for now as the data isn't very useful (doesn't include how promotions affected sales and all the promotions were the same price)

desc table fact_customer_activity;

select *
from fact_sales
where product_key = '140297';

select *
from fact_returns
where return_number = '1309062041';

-- testing if sales == returns
SELECT COUNT(*)
FROM FACT_RETURNS r
JOIN FACT_SALES s
    ON r.RETURN_NUMBER = s.ORDER_NUMBER
   AND r.CUSTOMER_KEY = s.CUSTOMER_KEY;

SELECT COUNT(*)
FROM FACT_RETURNS;

SELECT COUNT(*)
FROM FACT_SALES s
JOIN FACT_RETURNS r
  ON s.customer_key = r.customer_key;
AND r.CUSTOMER_KEY = s.CUSTOMER_KEY