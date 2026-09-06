-- Create dimensional model tables for customer intelligence

CREATE OR REPLACE TABLE MODELLED.DIM_CUSTOMER AS
SELECT
    -- Customer
    c.C_CUSTOMER_SK,
    c.C_CUSTOMER_ID,
    c.C_FIRST_NAME,
    c.C_LAST_NAME,
    c.C_EMAIL_ADDRESS,

    -- Age
    c.C_BIRTH_YEAR,
    c.CUSTOMER_AGE,
    c.AGE_GROUP,

    -- Demographics
    cd.CD_GENDER,
    cd.CD_MARITAL_STATUS,
    cd.CD_EDUCATION_STATUS,
    cd.CD_PURCHASE_ESTIMATE,
    cd.CD_CREDIT_RATING,
    cd.CD_DEP_EMPLOYED_COUNT,
    cd.CD_DEP_COLLEGE_COUNT,

    -- Household
    hd.HD_BUY_POTENTIAL,
    hd.HD_DEP_COUNT,
    hd.HD_VEHICLE_COUNT,

    -- Income
    ib.IB_LOWER_BOUND,
    ib.IB_UPPER_BOUND,

    -- Concat into one column for easier use in power BI
    CONCAT(
        ib.IB_LOWER_BOUND,
        ' - ',
        ib.IB_UPPER_BOUND
    ) AS INCOME_BAND,


    -- Location
    ca.CA_CITY,
    ca.CA_STATE,
    ca.CA_COUNTRY,
    ca.CA_ZIP,

    -- Metadata
    c.LOAD_DATE

FROM CURATED.CUSTOMER c

LEFT JOIN CURATED.CUSTOMER_ADDRESS ca
    ON c.C_CURRENT_ADDR_SK = ca.CA_ADDRESS_SK

LEFT JOIN CURATED.CUSTOMER_DEMOGRAPHICS cd
    ON c.C_CURRENT_CDEMO_SK = cd.CD_DEMO_SK

LEFT JOIN CURATED.HOUSEHOLD_DEMOGRAPHICS hd
    ON c.C_CURRENT_HDEMO_SK = hd.HD_DEMO_SK

LEFT JOIN CURATED.INCOME_BAND ib
    ON hd.HD_INCOME_BAND_SK = ib.IB_INCOME_BAND_SK;


select *
FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.DATE_DIM;


CREATE OR REPLACE TABLE MODELLED.DIM_DATE AS

SELECT

    /* Primary Key */
    D_DATE_SK,

    /* Date Fields */
    D_DATE_ID,
    D_DATE,

    /* Calendar Hierarchy */
    D_YEAR,
    D_QUARTER_SEQ,
    D_QUARTER_NAME,

    D_MONTH_SEQ,
    D_MOY           AS MONTH_NUMBER,
    TRIM(TO_CHAR(D_DATE, 'Month')) AS MONTH_NAME,

    D_WEEK_SEQ,
    D_DOW           AS DAY_OF_WEEK,
    D_DOM           AS DAY_OF_MONTH,

    D_DAY_NAME,
    D_QOY           AS QUARTER_OF_YEAR,

    /* Fiscal Calendar */
    D_FY_YEAR,
    D_FY_QUARTER_SEQ,
    D_FY_WEEK_SEQ,

    /* Flags */
    D_HOLIDAY,
    D_WEEKEND,
    D_FOLLOWING_HOLIDAY,

    D_CURRENT_DAY,
    D_CURRENT_WEEK,
    D_CURRENT_MONTH,
    D_CURRENT_QUARTER,
    D_CURRENT_YEAR,

    /* Relative Dates */
    D_FIRST_DOM,
    D_LAST_DOM,
    D_SAME_DAY_LY,
    D_SAME_DAY_LQ,

    /* Analytics-Friendly Derived Columns */

    CASE
        WHEN D_WEEKEND = 'Y'
        THEN 'Weekend'
        ELSE 'Weekday'
    END AS DAY_TYPE,

    CASE
        WHEN D_MOY IN (12,1,2) THEN 'Winter'
        WHEN D_MOY IN (3,4,5) THEN 'Spring'
        WHEN D_MOY IN (6,7,8) THEN 'Summer'
        ELSE 'Autumn'
    END AS SEASON,

    CONCAT(
        D_YEAR,
        '-Q',
        D_QOY
    ) AS YEAR_QUARTER,

    CONCAT(
        D_YEAR,
        '-',
        LPAD(D_MOY,2,'0')
    ) AS YEAR_MONTH

FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.DATE_DIM;

select *
from dim_date;


select *
from CURATED.item
limit 100;

describe table CURATED.item;


-- dimension table product, will mostly use item

CREATE OR REPLACE TABLE MODELLED.DIM_PRODUCT AS
SELECT
    ITEM_SK,
    ITEM_ID,
    PRODUCT_NAME,
    ITEM_DESC,
    CATEGORY,
    CLASS,
    BRAND,
    MANUFACT,
    SIZE,
    COLOR,
    FORMULATION,
    UNITS,
    CURRENT_PRICE,
    WHOLESALE_COST,
    LOAD_DATE,
FROM CURATED.ITEM;

-- dimensional table store

CREATE OR REPLACE TABLE MODELLED.DIM_STORE AS
SELECT

    /* Primary Key */
    S_STORE_SK AS STORE_KEY,

    /* Business Key */
    S_STORE_ID AS STORE_ID,

    /* Store Information */
    TRIM(S_STORE_NAME) AS STORE_NAME,
    S_MANAGER AS STORE_MANAGER,

    /* Capacity & Operations */
    S_NUMBER_EMPLOYEES AS EMPLOYEE_COUNT,
    S_FLOOR_SPACE AS FLOOR_SPACE_SQFT,
    S_HOURS AS STORE_HOURS,

    /* Organisation Hierarchy */

     -- divison and market id are both 1 so no point having them
    S_MARKET_MANAGER AS MARKET_MANAGER,

    /* Location */
    CONCAT_WS(
        ' ',
        S_STREET_NUMBER,
        S_STREET_NAME,
        S_STREET_TYPE
    ) AS STREET_ADDRESS,

    S_SUITE_NUMBER AS SUITE_NUMBER,
    S_CITY AS CITY,
    S_COUNTY AS COUNTY,
    S_STATE AS STATE,
    S_ZIP AS POSTAL_CODE,
    S_COUNTRY AS COUNTRY,

    /* Time & Tax */
    S_GMT_OFFSET AS GMT_OFFSET,
    S_TAX_PRECENTAGE AS TAX_RATE,

    /* Lifecycle */
    S_REC_START_DATE AS EFFECTIVE_START_DATE,
    S_REC_END_DATE AS EFFECTIVE_END_DATE,
    S_CLOSED_DATE_SK AS CLOSED_DATE_KEY,

    /* Derived Columns */
    DATEDIFF(
    YEAR,
    S_REC_START_DATE,
    CURRENT_DATE()
    ) AS STORE_AGE_YEARS,

    CASE
        WHEN S_REC_END_DATE IS NULL THEN 'Current'
        ELSE 'Historical'
    END AS STORE_STATUS,

    CASE
        WHEN S_CLOSED_DATE_SK IS NULL THEN 'Open'
        ELSE 'Closed'
    END AS OPERATIONAL_STATUS,

    CASE
        WHEN S_NUMBER_EMPLOYEES < 230 THEN 'Small'
        WHEN S_NUMBER_EMPLOYEES < 270 THEN 'Medium'
        ELSE 'Large'
    END AS STORE_SIZE,

    CASE
        WHEN S_FLOOR_SPACE < 6500000 THEN 'Small Footprint'
        WHEN S_FLOOR_SPACE < 8500000 THEN 'Medium Footprint'
        ELSE 'Large Footprint'
    END AS FLOOR_SPACE_CATEGORY

FROM RAW.STORE
WHERE S_STORE_SK IS NOT NULL;

select *
from dim_store;

CREATE OR REPLACE TABLE MODELLED.DIM_REGION AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY COUNTRY, STATE, COUNTY
    ) AS REGION_KEY,
    COUNTRY,
    STATE,
    COUNTY,
    REGION
FROM (
    /* Customer Geography */
    SELECT
        COALESCE(CA_COUNTRY, 'United States') AS COUNTRY,
        COALESCE(CA_STATE, 'UNKNOWN') AS STATE,
        COALESCE(CA_COUNTY, 'UNKNOWN') AS COUNTY,
        REGION
    FROM CURATED.CUSTOMER_ADDRESS
    UNION
    /* Store Geography */
    SELECT
        COALESCE(COUNTRY, 'United States') AS COUNTRY,
        COALESCE(STATE, 'UNKNOWN') AS STATE,
        COALESCE(COUNTY, 'UNKNOWN') AS COUNTY,
        CASE
            WHEN STATE IN ('CA','OR','WA','AK','HI')
                THEN 'WEST'
            WHEN STATE IN ('NY','NJ','MA','CT','RI','VT','NH','ME','PA')
                THEN 'EAST'
            WHEN STATE IN ('TX','OK','FL','GA','AL','MS','LA','SC',
                             'NC','TN','KY','VA','WV','AR')
                THEN 'SOUTH'
            WHEN STATE IN ('IL','IN','IA','KS','MI','MN','MO',
                             'NE','ND','OH','SD','WI')
                THEN 'MIDWEST'
            ELSE 'OTHER'
        END AS REGION
    FROM MODELLED.DIM_STORE
    UNION
    /* Warehouse Geography */
    SELECT
        COALESCE(COUNTRY, 'United States') AS COUNTRY,
        COALESCE(STATE, 'UNKNOWN') AS STATE,
        COALESCE(COUNTY, 'UNKNOWN') AS COUNTY,
        CASE
            WHEN STATE IN ('CA','OR','WA','AK','HI')
                THEN 'WEST'
            WHEN STATE IN ('NY','NJ','MA','CT','RI','VT','NH','ME','PA')
                THEN 'EAST'
            WHEN STATE IN ('TX','OK','FL','GA','AL','MS','LA','SC',
                           'NC','TN','KY','VA','WV','AR')
                THEN 'SOUTH'
            WHEN STATE IN ('IL','IN','IA','KS','MI','MN','MO',
                           'NE','ND','OH','SD','WI')
                THEN 'MIDWEST'
            ELSE 'OTHER'
        END AS REGION
    FROM CURATED.WAREHOUSE
) GEO;


-- Region dimensional table
select *
from dim_region;

select *
from dim_store;

CREATE OR REPLACE TABLE MODELLED.DIM_PROMOTION AS

SELECT

    /* Primary Key */
    PROMO_SK AS PROMOTION_KEY,

    /* Business Key */
    PROMO_ID AS PROMOTION_ID,

    /* Date Keys */
    START_DATE_SK,
    END_DATE_SK,

    /* Product Relationship */
    ITEM_SK AS PRODUCT_KEY,

    /* Promotion Details */
    PROMO_NAME,

    /* Metrics */
    COST AS PROMOTION_COST,
    RESPONSE_TARGET,

    /* Primary Marketing Channel */
    CASE
        WHEN CHANNEL_EMAIL = 'Y' THEN 'Email'
        WHEN CHANNEL_TV = 'Y' THEN 'TV'
        WHEN CHANNEL_RADIO = 'Y' THEN 'Radio'
        WHEN CHANNEL_CATALOG = 'Y' THEN 'Catalog'
        WHEN CHANNEL_DMAIL = 'Y' THEN 'Direct Mail'
        WHEN CHANNEL_EVENT = 'Y' THEN 'Event'
        WHEN CHANNEL_DEMO = 'Y' THEN 'Demo'
        WHEN CHANNEL_PRESS = 'Y' THEN 'Press'
        ELSE 'No Channel'
    END AS PRIMARY_CHANNEL,

    /* Promotion Status */
    CASE
        WHEN START_DATE_SK IS NULL
          OR END_DATE_SK IS NULL
        THEN 'Incomplete'
        ELSE 'Active Campaign'
    END AS PROMOTION_STATUS

FROM CURATED.PROMOTION;

