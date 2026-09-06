import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

st.set_page_config(layout="wide")
session = get_active_session()

st.title("Customer 360 Dashboard")

# --- KPI row ---
kpi_df = session.sql("""
    SELECT
        SUM(LIFETIME_SPEND) AS TOTAL_SPEND,
        COUNT(DISTINCT CUSTOMER_KEY) AS TOTAL_CUSTOMERS,
        AVG(AVERAGE_ORDER_VALUE) AS AVG_ORDER_VALUE
    FROM CUSTOMER_INTELLIGENCE.CONSUMER.CUSTOMER_360
""").to_pandas()

col1, col2, col3 = st.columns(3)
col1.metric("Total Lifetime Spend", f"${kpi_df['TOTAL_SPEND'][0]:,.0f}")
col2.metric("Total Customers", f"{kpi_df['TOTAL_CUSTOMERS'][0]:,}")
col3.metric("Avg Order Value", f"${kpi_df['AVG_ORDER_VALUE'][0]:,.2f}")

st.divider()

# --- Segment spend chart ---
st.subheader("Spend by Customer Segment")
seg_df = session.sql("""
    SELECT
        seg.CUSTOMER_VALUE_SEGMENT,
        COUNT(*) AS CUSTOMER_COUNT,
        SUM(c.LIFETIME_SPEND) AS SEGMENT_SPEND
    FROM CUSTOMER_INTELLIGENCE.CONSUMER.CUSTOMER_SEGMENTATION seg
    JOIN CUSTOMER_INTELLIGENCE.CONSUMER.CUSTOMER_360 c
        ON seg.CUSTOMER_KEY = c.CUSTOMER_KEY
    GROUP BY seg.CUSTOMER_VALUE_SEGMENT
    ORDER BY SEGMENT_SPEND DESC
""").to_pandas()
st.bar_chart(seg_df.set_index("CUSTOMER_VALUE_SEGMENT")["SEGMENT_SPEND"])

# --- Return behaviour --- (return value from customers)
st.subheader("Return Behaviour Distribution - Return Value Including all Orders")
ret_df = session.sql("""
    SELECT RETURN_BEHAVIOUR_SEGMENT, COUNT(*) AS CUSTOMERS, SUM(RETURN_VALUE) AS RETURN_VALUE
    FROM CUSTOMER_INTELLIGENCE.CONSUMER.RETURNS_INTELLIGENCE
    GROUP BY RETURN_BEHAVIOUR_SEGMENT
""").to_pandas()
st.bar_chart(ret_df.set_index("RETURN_BEHAVIOUR_SEGMENT")["CUSTOMERS"])

# --- Store performance table ---
st.subheader("Store Performance")
store_df = session.sql("""
    SELECT REGION, STORE_NAME, TOTAL_SALES, SALES_PER_SQFT, RETURN_RATE
    FROM CUSTOMER_INTELLIGENCE.CONSUMER.REGION_STORE_PERFORMANCE
    ORDER BY TOTAL_SALES DESC
    LIMIT 20
""").to_pandas()
st.dataframe(store_df, use_container_width=True)

# --- Top customers ---
st.subheader("Top 10 Customers by Spend")
top_df = session.sql("""
    SELECT CUSTOMER_NAME, LIFETIME_SPEND, TOTAL_ORDERS, RECENCY_DAYS
    FROM CUSTOMER_INTELLIGENCE.CONSUMER.CUSTOMER_360
    ORDER BY LIFETIME_SPEND DESC
    LIMIT 10
""").to_pandas()
st.dataframe(top_df, use_container_width=True)

col_a, col_b = st.columns(2)

with col_a:
    # --- Return rate by gender ---
    st.subheader("Return Rate by Gender")
    demo_gender_df = session.sql("""
        SELECT
            COALESCE(CD_GENDER, 'UNKNOWN') AS GENDER,
            SUM(RETURN_FREQUENCY) AS TOTAL_RETURNS,
            SUM(TOTAL_ORDERS) AS TOTAL_ORDERS,
            SUM(RETURN_FREQUENCY) / NULLIF(SUM(TOTAL_ORDERS), 0) AS RETURN_RATE
        FROM CUSTOMER_INTELLIGENCE.CONSUMER.RETURNS_INTELLIGENCE
        GROUP BY 1
        ORDER BY RETURN_RATE DESC
    """).to_pandas()
    st.bar_chart(demo_gender_df.set_index("GENDER")["RETURN_RATE"])

with col_b:
    # --- Average order value by income band ---
    st.subheader("Average Order Value by Income Band")
    aov_income_df = session.sql("""
        SELECT
            COALESCE(INCOME_BAND, 'UNKNOWN') AS INCOME_BAND,
            AVG(AVERAGE_ORDER_VALUE) AS AVG_ORDER_VALUE,
            COUNT(*) AS CUSTOMER_COUNT
        FROM CUSTOMER_INTELLIGENCE.CONSUMER.CUSTOMER_360
        WHERE TOTAL_ORDERS > 0
        GROUP BY 1
        ORDER BY AVG_ORDER_VALUE DESC
        LIMIT 15
    """).to_pandas()
    st.bar_chart(aov_income_df.set_index("INCOME_BAND")["AVG_ORDER_VALUE"])

st.divider()

# --- AOV by segment ---
st.subheader("Average Order Value by Customer Segment")
aov_seg_df = session.sql("""
    SELECT
        seg.CUSTOMER_VALUE_SEGMENT,
        AVG(c.AVERAGE_ORDER_VALUE) AS AVG_ORDER_VALUE
    FROM CUSTOMER_INTELLIGENCE.CONSUMER.CUSTOMER_SEGMENTATION seg
    JOIN CUSTOMER_INTELLIGENCE.CONSUMER.CUSTOMER_360 c
        ON seg.CUSTOMER_KEY = c.CUSTOMER_KEY
    GROUP BY seg.CUSTOMER_VALUE_SEGMENT
    ORDER BY AVG_ORDER_VALUE DESC
""").to_pandas()
st.bar_chart(aov_seg_df.set_index("CUSTOMER_VALUE_SEGMENT")["AVG_ORDER_VALUE"])

st.divider()
st.header("Product Performance")

col_p1, col_p2 = st.columns(2)

with col_p1:
    st.subheader("Top 10 Most Popular Products")
    top_popular = session.sql("""
        SELECT PRODUCT_NAME, TOTAL_UNITS_SOLD, TOTAL_REVENUE
        FROM CUSTOMER_INTELLIGENCE.CONSUMER.PRODUCT_PERFORMANCE
        ORDER BY TOTAL_UNITS_SOLD DESC
        LIMIT 10
    """).to_pandas()
    st.dataframe(top_popular, use_container_width=True, hide_index=True)

with col_p2:
    st.subheader("Top 10 Most Profitable Products")
    top_profit = session.sql("""
        SELECT PRODUCT_NAME, TOTAL_PROFIT, PROFIT_MARGIN
        FROM CUSTOMER_INTELLIGENCE.CONSUMER.PRODUCT_PERFORMANCE
        ORDER BY TOTAL_PROFIT DESC
        LIMIT 10
    """).to_pandas()
    st.dataframe(top_profit, use_container_width=True, hide_index=True)

st.subheader("Popular but Low-Profitability Products")
st.caption("Top 20% by units sold, bottom 20% by profit margin")
low_margin_popular = session.sql("""
    WITH ranked AS (
        SELECT
            PRODUCT_NAME,
            TOTAL_UNITS_SOLD,
            PROFIT_MARGIN,
            NTILE(5) OVER (ORDER BY TOTAL_UNITS_SOLD DESC) AS POPULARITY_BUCKET,
            NTILE(5) OVER (ORDER BY PROFIT_MARGIN ASC) AS MARGIN_BUCKET
        FROM CUSTOMER_INTELLIGENCE.CONSUMER.PRODUCT_PERFORMANCE
        WHERE TOTAL_UNITS_SOLD > 0
    )
    SELECT PRODUCT_NAME, TOTAL_UNITS_SOLD, PROFIT_MARGIN
    FROM ranked
    WHERE POPULARITY_BUCKET = 1 AND MARGIN_BUCKET = 1
    ORDER BY TOTAL_UNITS_SOLD DESC
""").to_pandas()
st.dataframe(low_margin_popular, use_container_width=True)

st.subheader("Highest Return Rate Products")
top_returns = session.sql("""
    SELECT PRODUCT_NAME, RETURN_RATE, RETURN_COUNT, TOTAL_UNITS_SOLD
    FROM CUSTOMER_INTELLIGENCE.CONSUMER.PRODUCT_PERFORMANCE
    WHERE TOTAL_UNITS_SOLD >= 10
    ORDER BY RETURN_RATE DESC
    LIMIT 10
""").to_pandas()
st.dataframe(top_returns, use_container_width=True)

st.divider()
st.header("Order & Time Trends")

col_t1, col_t2 = st.columns(2)

with col_t1:
    st.subheader("Average Basket Size")
    basket_df = session.sql("""
        SELECT
            SUM(QUANTITY) / NULLIF(COUNT(DISTINCT ORDER_NUMBER), 0) AS AVG_ITEMS_PER_ORDER
        FROM CUSTOMER_INTELLIGENCE.MODELLED.FACT_SALES
    """).to_pandas()
    st.metric("Avg Items per Order", f"{basket_df['AVG_ITEMS_PER_ORDER'][0]:.2f}")

with col_t2:
    st.subheader("Sales by Quarter")
    quarter_df = session.sql("""
        SELECT
            dd.YEAR_QUARTER,
            SUM(fs.NET_PAID) AS TOTAL_SALES
        FROM CUSTOMER_INTELLIGENCE.MODELLED.FACT_SALES fs
        JOIN CUSTOMER_INTELLIGENCE.MODELLED.DIM_DATE dd
            ON fs.DATE_KEY = dd.D_DATE_SK
        GROUP BY dd.YEAR_QUARTER
        ORDER BY dd.YEAR_QUARTER
    """).to_pandas()
    st.line_chart(quarter_df.set_index("YEAR_QUARTER")["TOTAL_SALES"])

st.subheader("Sales by Month")
month_df = session.sql("""
    SELECT
        dd.YEAR_MONTH,
        SUM(fs.NET_PAID) AS TOTAL_SALES
    FROM CUSTOMER_INTELLIGENCE.MODELLED.FACT_SALES fs
    JOIN CUSTOMER_INTELLIGENCE.MODELLED.DIM_DATE dd
        ON fs.DATE_KEY = dd.D_DATE_SK
    GROUP BY dd.YEAR_MONTH
    ORDER BY dd.YEAR_MONTH
""").to_pandas()
st.line_chart(month_df.set_index("YEAR_MONTH")["TOTAL_SALES"])

st.divider()
st.header("Region Performance")

region_agg_df = session.sql("""
    SELECT
        REGION,
        COUNT(DISTINCT STORE_KEY) AS STORE_COUNT,
        SUM(TOTAL_ORDERS) AS TOTAL_ORDERS,
        SUM(TOTAL_SALES) AS TOTAL_SALES,
        SUM(TOTAL_PROFIT) AS TOTAL_PROFIT
    FROM CUSTOMER_INTELLIGENCE.CONSUMER.REGION_STORE_PERFORMANCE
    GROUP BY REGION
""").to_pandas()

col_r1, col_r2 = st.columns(2)

with col_r1:
    st.subheader("Top Regions by Profit")
    top_profit_regions = region_agg_df.sort_values("TOTAL_PROFIT", ascending=False).head(10)
    st.bar_chart(top_profit_regions.set_index("REGION")["TOTAL_PROFIT"])
    st.dataframe(
        top_profit_regions[["REGION", "TOTAL_PROFIT", "TOTAL_ORDERS"]],
        use_container_width=True
    )

with col_r2:
    st.subheader("Bottom Regions by Profit")
    bottom_profit_regions = region_agg_df.sort_values("TOTAL_PROFIT", ascending=True).head(10)
    st.bar_chart(bottom_profit_regions.set_index("REGION")["TOTAL_PROFIT"])
    st.dataframe(
        bottom_profit_regions[["REGION", "TOTAL_PROFIT", "TOTAL_ORDERS"]],
        use_container_width=True
    )

st.subheader("Regions by Sales Volume (Number of Orders)")
top_sales_regions = region_agg_df.sort_values("TOTAL_ORDERS", ascending=False).head(10)
st.bar_chart(top_sales_regions.set_index("REGION")["TOTAL_ORDERS"])
st.dataframe(
    top_sales_regions[["REGION", "TOTAL_ORDERS", "TOTAL_SALES", "TOTAL_PROFIT"]],
    use_container_width=True
)

st.divider()
st.header("Sales Trends & Channel Performance")

col_t1, col_t2 = st.columns(2)

with col_t1:
    st.subheader("Sales by Day of Week")
    dow_df = session.sql("""
        SELECT
            D_DAY_NAME AS DAY_OF_WEEK,
            DAY_OF_WEEK AS DAY_NUMBER,
            SUM(TOTAL_SALES) AS TOTAL_SALES
        FROM CUSTOMER_INTELLIGENCE.CONSUMER.SALES_TIME_CHANNEL_PERFORMANCE
        GROUP BY D_DAY_NAME, DAY_OF_WEEK
        ORDER BY DAY_OF_WEEK
    """).to_pandas()
    st.bar_chart(dow_df.set_index("DAY_OF_WEEK")["TOTAL_SALES"])

with col_t2:
    st.subheader("Sales by Channel")
    channel_df = session.sql("""
        SELECT
            SALES_CHANNEL,
            SUM(TOTAL_SALES) AS TOTAL_SALES,
            SUM(TOTAL_PROFIT) AS TOTAL_PROFIT,
            SUM(TOTAL_ORDERS) AS TOTAL_ORDERS
        FROM CUSTOMER_INTELLIGENCE.CONSUMER.SALES_TIME_CHANNEL_PERFORMANCE
        GROUP BY SALES_CHANNEL
        ORDER BY TOTAL_SALES DESC
    """).to_pandas()
    st.dataframe(channel_df, use_container_width=True, hide_index=True)