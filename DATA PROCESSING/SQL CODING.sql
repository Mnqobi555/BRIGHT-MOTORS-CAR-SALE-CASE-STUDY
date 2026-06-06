-- Databricks notebook source
select * from workspace.default.car_sale_data;

--Handling text written prices to standard currency
select
TRY_CAST(REGEXP_REPLACE(selling_price, '[^0-9.]', '') AS DOUBLE)
from workspace.default.car_sale_data;


--------------------------------------------------------------
--1.CHECKING THE DATE RANGE
--------------------------------------------------------------

--Data collection started on 2014-01-01 and the last day of data collection was 2015-07-21
SELECT
    MIN(try_to_date(sale_date, 'dd/MM/yyyy')) AS data_collection_start,
    MAX(try_to_date(sale_date, 'dd/MM/yyyy')) AS data_collection_end,
    DATEDIFF(MAX(try_to_date(sale_date, 'dd/MM/yyyy')), MIN(try_to_date(sale_date, 'dd/MM/yyyy'))) AS total_days_collected,
    COUNT(*) AS total_records

from workspace.default.car_sale_data;

---------------------------------------------
--2.DISTINCT SELLERS AND STATES
---------------------------------------------
 
--All unique sellers total to 14261
SELECT DISTINCT seller
FROM  workspace.default.car_sale_data
ORDER BY seller;
 
--All unique states total to 38
SELECT DISTINCT state
FROM  workspace.default.car_sale_data
ORDER BY state;
 
--Combined: seller–state pairs (useful for geographic seller mapping)
SELECT DISTINCT
    seller,
    state
FROM workspace.default.car_sale_data
ORDER BY seller, state;

---------------------------------------------
--3.ALL CAR MAKES AND MODELS BEING SOLD
---------------------------------------------

--Total number of makes being sold = 97
SELECT
    make,
    COUNT(*) AS total_units_sold
FROM  workspace.default.car_sale_data
WHERE make IS NOT NULL
GROUP BY make
ORDER BY total_units_sold DESC;

--From the 97 makes we have 973 models 
SELECT
    model,
    COUNT(*) AS total_units_sold
FROM workspace.default.car_sale_data
WHERE model IS NOT NULL
  AND TRIM(model) != ''       
GROUP BY model
ORDER BY total_units_sold DESC;

--From the 973 models available the years range from 1982-2015
SELECT
    year,
    COUNT(*) AS total_units_sold
FROM workspace.default.car_sale_data
WHERE year IS NOT NULL
  AND TRIM(year) != ''       
GROUP BY year
ORDER BY year DESC;


-------------------------------------------------
--4.MAKES SOLD ACROSS EACH SELLER AND STATE
-------------------------------------------------

SELECT
    seller,
    state,
    make,
    COUNT(*) AS units_sold,
    ROUND(SUM(selling_price), 2) AS total_revenue
FROM   workspace.default.car_sale_data
GROUP BY seller, state, make
ORDER BY seller, state, units_sold DESC;

-------------------------------------------------
--5.OVERALL SALES TRANSACTIONS & REVENUE
-------------------------------------------------

SELECT
--Total Transactions = 558811
    COUNT(*) AS total_transactions,
--Total Revenue = 7606012287
    ROUND(SUM(selling_price),2) AS total_revenue,
--Total Cost = 7694314375
    ROUND(SUM(mmr),2)AS total_cost,
--Total Profit = -88302088
    ROUND(SUM(selling_price - mmr), 2) AS total_profit,
--Profit margin = -1.16%
 ROUND((SUM(selling_price - mmr) / NULLIF(SUM(selling_price), 0)) * 100, 2) AS profit_margin
    
FROM workspace.default.car_sale_data;

-------------------------------------------------------
--6.TRANSACTIONS CLASSIFIED BY TIME OF DAY
-------------------------------------------------------

UPDATE workspace.default.car_sale_data
SET time_of_day = 
    CASE
        WHEN sale_time IS NULL THEN 'Unknown'
        WHEN HOUR(CAST(sale_time AS TIMESTAMP)) BETWEEN 0 AND 5 THEN 'Early Morning'
        WHEN HOUR(CAST(sale_time AS TIMESTAMP)) BETWEEN 6 AND 11 THEN 'Morning'
        WHEN HOUR(CAST(sale_time AS TIMESTAMP)) BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN HOUR(CAST(sale_time AS TIMESTAMP)) BETWEEN 17 AND 23 THEN 'Evening'
        WHEN CAST(SUBSTR(sale_time, 1, 2) AS INT) BETWEEN 0 AND 5 THEN 'Early Morning'
        WHEN CAST(SUBSTR(sale_time, 1, 2) AS INT) BETWEEN 6 AND 11 THEN 'Morning'
        WHEN CAST(SUBSTR(sale_time, 1, 2) AS INT) BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN CAST(SUBSTR(sale_time, 1, 2) AS INT) BETWEEN 17 AND 23 THEN 'Evening'
        ELSE 'Unknown'
    END;
-------------------------------------------------------
--7.BEST PERFORMING REGIONS
-------------------------------------------------------

--Top 5 nc,tn,wa,ca and nv
--Bottom 5 nj,fl,tx,pa,md
SELECT
    state,
    COUNT(*) AS units_sold,
    ROUND(SUM(selling_price), 2) AS total_revenue,
    ROUND(SUM(selling_price - mmr), 2) AS total_profit

FROM workspace.default.car_sale_data

WHERE selling_price IS NOT NULL
  AND mmr IS NOT NULL
  AND state IS NOT NULL

GROUP BY state
ORDER BY total_profit DESC;

------------------------------------------------------------------------------
--8.PROFIT CALCULATION //Profit = (Selling_Price - Cost_Price) * Units_Sold//
------------------------------------------------------------------------------

--By Make 
SELECT
    make,
    COUNT(*) AS units_sold,
    ROUND(AVG(selling_price - mmr), 2) AS avg_profit_per_unit,
    ROUND(SUM(selling_price - mmr), 2) AS total_profit,
    ROUND(SUM(selling_price), 2) AS total_revenue,
    ROUND((SUM(selling_price - mmr) / NULLIF(SUM(selling_price), 0)) * 100,2) AS profit_margin_percentage

FROM workspace.default.car_sale_data
WHERE make IS NOT NULL

GROUP BY make
ORDER BY total_profit DESC;

--By Seller
SELECT
    seller,
    COUNT(*) AS units_sold,
    ROUND(SUM(selling_price - mmr), 2) AS total_profit,
    ROUND(SUM(selling_price), 2) AS total_revenue,
    ROUND(
        (SUM(selling_price - mmr) / NULLIF(SUM(selling_price), 0)) * 100,
    2) AS profit_margin_percentage

FROM workspace.default.car_sale_data
WHERE seller IS NOT NULL

GROUP BY seller
ORDER BY total_profit DESC;


------------------------------------------------------------------------------
--9.GROUPING TRANSACTIONS BY TIME PERIOD (Month / Quarter / Year)
------------------------------------------------------------------------------

-- Monthly
WITH base AS (
    SELECT
        selling_price,
        mmr,
        try_to_date(sale_date, 'dd/MM/yyyy') AS Assumed_date
    FROM workspace.default.car_sale_data
    WHERE try_to_date(sale_date, 'dd/MM/yyyy') IS NOT NULL
      AND selling_price IS NOT NULL
      AND mmr IS NOT NULL
)

SELECT
    YEAR(Assumed_date) AS sale_year,
    MONTH(Assumed_date) AS sale_month,
    DATE_FORMAT(Assumed_date, 'MMM') AS sale_month_label,

    COUNT(*) AS transactions,
    ROUND(SUM(selling_price), 2) AS total_revenue
   
FROM base

GROUP BY
    YEAR(Assumed_date),
    MONTH(Assumed_date),
    DATE_FORMAT(Assumed_date, 'MMM')

ORDER BY
    sale_year,
    sale_month;


 -- Quarterly
WITH base AS (
    SELECT
        selling_price,
        mmr,
        try_to_date(sale_date, 'dd/MM/yyyy') AS assumed_date
    FROM workspace.default.car_sale_data
    WHERE try_to_date(sale_date, 'dd/MM/yyyy') IS NOT NULL
      AND selling_price IS NOT NULL
      AND mmr IS NOT NULL
)

SELECT
    YEAR(assumed_date) AS sale_year,
    QUARTER(assumed_date) AS sale_quarter,
    CONCAT('Q', QUARTER(assumed_date)) AS sale_quarter_label,

    COUNT(*) AS transactions,
    ROUND(SUM(selling_price), 2) AS total_revenue
    
FROM base

GROUP BY
    YEAR(assumed_date),
    QUARTER(assumed_date)

ORDER BY
    sale_year,
    sale_quarter;

-- Yearly
WITH base AS (
    SELECT
        selling_price,
        mmr,
        try_to_date(sale_date, 'dd/MM/yyyy') AS assumed_date
    FROM workspace.default.car_sale_data
    WHERE try_to_date(sale_date, 'dd/MM/yyyy') IS NOT NULL
      AND selling_price IS NOT NULL
      AND mmr IS NOT NULL
)

SELECT
    YEAR(assumed_date) AS sale_year,

    COUNT(*) AS transactions,
    ROUND(SUM(selling_price), 2) AS total_revenue,
    ROUND(SUM(selling_price - mmr), 2) AS total_profit

FROM base

GROUP BY
    YEAR(assumed_date)

ORDER BY
    sale_year;
    
-------------------------------------------------------------------------------------
--10.CATEGORISING CAR BY PERFORMNACE TIERS (High Margin, Medium Margin & Low Margin)
-------------------------------------------------------------------------------------

WITH base AS (
    SELECT
        make,
        selling_price,
        mmr AS cost_price,

        (selling_price - mmr) AS profit
    FROM workspace.default.car_sale_data
    WHERE selling_price IS NOT NULL
      AND mmr IS NOT NULL
      AND make IS NOT NULL
),

aggregated AS (
    SELECT
        make,
        COUNT(*) AS units_sold,
        SUM(selling_price) AS total_revenue,
        SUM(cost_price) AS total_cost,
        SUM(profit) AS total_profit,
        (SUM(profit) / NULLIF(SUM(selling_price), 0)) * 100 AS profit_margin_pct
    FROM base
    GROUP BY make
)

SELECT
    make,
    units_sold,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(total_profit, 2) AS total_profit,
    ROUND(profit_margin_pct, 2) AS profit_margin_pct,

    -- Performance Tier by Make
    CASE
        WHEN profit_margin_pct >= 20 THEN 'High Margin'
        WHEN profit_margin_pct BETWEEN 10 AND 19.99 THEN 'Medium Margin'
        ELSE 'Low Margin'
    END AS performance_tier

FROM aggregated
ORDER BY total_profit DESC;

SELECT * FROM workspace.default.car_sale_data LIMIT 100000 OFFSET 0;
SELECT * FROM workspace.default.car_sale_data LIMIT 100000 OFFSET 100000;
SELECT * FROM workspace.default.car_sale_data LIMIT 100000 OFFSET 200000;
SELECT * FROM workspace.default.car_sale_data LIMIT 100000 OFFSET 300000;
SELECT * FROM workspace.default.car_sale_data LIMIT 100000 OFFSET 400000;
SELECT * FROM workspace.default.car_sale_data LIMIT 100000 OFFSET 500000;