/* 
   DINGDONG FRESH RETAIL SALES & INVENTORY ANALYSIS
   ANALYSIS SQL Script
   Database: MySQL
   Client: HeidiSQL
   Study period: 2024-03-28 to 2024-06-25
   Dataset: 89,100 observations
   

   IMPORTANT NOTES
   ---------------
   1. sale_amount is normalized demand/sales quantity, NOT revenue.
   2. discount = 0 is treated as a data-quality review case.
   3. Statistical outliers are retained because they are operationally plausible.
   4. The raw table should remain unchanged. Analysis is performed through a question format.
*/



/* 
   1. DATABASE SETUP
*/

CREATE DATABASE IF NOT EXISTS dingdong_retail;
USE dingdong_retail;

CREATE TABLE IF NOT EXISTS retail_raw (
    city_id INT NOT NULL,
    store_id INT NOT NULL,
    first_category_id INT NOT NULL,
    second_category_id INT NOT NULL,
    product_id INT NOT NULL,
    dt DATE NOT NULL,
    sale_amount DOUBLE NOT NULL,
    stock_hour6_22_cnt INT NOT NULL,
    discount DOUBLE NOT NULL,
    holiday_flag INT NOT NULL,
    activity_flag INT NOT NULL,
    precpt DOUBLE NOT NULL,
    avg_temperature DOUBLE NOT NULL,
    avg_humidity DOUBLE NOT NULL
);


/*
   2. CREATE THE ANALYTICAL VIEW
*/

CREATE OR REPLACE VIEW vw_retail_analysis AS
SELECT
    city_id,
    store_id,
    first_category_id,
    second_category_id,
    product_id,
    dt,
    sale_amount,
    stock_hour6_22_cnt,
    discount,
    holiday_flag,
    activity_flag,
    precpt,
    avg_temperature,
    avg_humidity,

    CASE
        WHEN discount = 0 THEN 'Review'
        WHEN discount < 1 THEN 'Discounted'
        ELSE 'No Discount'
    END AS discount_status,

    CASE
        WHEN discount = 0 THEN NULL
        ELSE 1 - discount
    END AS discount_pct,

    CASE
        WHEN stock_hour6_22_cnt > 0 THEN 1
        ELSE 0
    END AS stockout_flag,

    CASE
        WHEN holiday_flag = 1 THEN 'Holiday'
        ELSE 'Non-Holiday'
    END AS holiday_type,

    CASE
        WHEN activity_flag = 1 THEN 'Promotion'
        ELSE 'No Promotion'
    END AS promotion_type,

    DAYNAME(dt) AS day_name,

    CASE
        WHEN DAYOFWEEK(dt) IN (1, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type,

    DATE_SUB(dt, INTERVAL WEEKDAY(dt) DAY) AS week_start

FROM retail_raw;


/* 
   3. OVERALL PROJECT KPIs
*/

SELECT
    COUNT(*) AS observations,
    COUNT(DISTINCT city_id) AS cities,
    COUNT(DISTINCT store_id) AS stores,
    COUNT(DISTINCT product_id) AS products,
    ROUND(SUM(sale_amount), 3) AS total_demand,
    ROUND(AVG(sale_amount), 3) AS average_demand,
    SUM(stock_hour6_22_cnt) AS total_stockout_hours,
    SUM(stockout_flag) AS stockout_observations,
    ROUND(
        100.0 * SUM(stockout_flag) / COUNT(*),
        2
    ) AS stockout_rate_pct
FROM vw_retail_analysis;


/* 
   4. DEMAND OVERVIEW
*/

SELECT
    city_id,
    ROUND(SUM(sale_amount), 3) AS total_demand,
    ROUND(AVG(sale_amount), 3) AS average_demand
FROM vw_retail_analysis
GROUP BY city_id
ORDER BY average_demand DESC;

SELECT
    store_id,
    COUNT(*) AS observations,
    ROUND(SUM(sale_amount), 3) AS total_demand,
    ROUND(AVG(sale_amount), 3) AS average_demand
FROM vw_retail_analysis
GROUP BY store_id
ORDER BY average_demand DESC;

SELECT
    first_category_id,
    ROUND(SUM(sale_amount), 3) AS total_demand,
    ROUND(AVG(sale_amount), 3) AS average_demand,
    COUNT(*) AS observations
FROM vw_retail_analysis
GROUP BY first_category_id
ORDER BY average_demand DESC;

SELECT
    first_category_id,
    second_category_id,
    ROUND(SUM(sale_amount), 3) AS total_demand,
    ROUND(AVG(sale_amount), 3) AS average_demand,
    COUNT(*) AS observations
FROM vw_retail_analysis
GROUP BY first_category_id, second_category_id
ORDER BY first_category_id, average_demand DESC;

/* 
   5. STORE STOCK-OUT ANALYSIS
 */

SELECT
    store_id,
    COUNT(*) AS observations,
    ROUND(SUM(sale_amount), 3) AS total_demand,
    ROUND(AVG(sale_amount), 3) AS average_demand,
    SUM(stock_hour6_22_cnt) AS total_stockout_hours,
    SUM(stockout_flag) AS stockout_observations,
    ROUND(100.0 * SUM(stockout_flag) / COUNT(*), 2) AS stockout_rate_pct
FROM vw_retail_analysis
GROUP BY store_id
ORDER BY stockout_rate_pct DESC;

/*
   6. STORE-PRODUCT INVENTORY SUMMARY
 */

CREATE OR REPLACE VIEW vw_store_product_summary AS
SELECT
    store_id,
    product_id,
    COUNT(*) AS observations,
    ROUND(SUM(sale_amount), 3) AS total_demand,
    ROUND(AVG(sale_amount), 6) AS avg_daily_demand,
    SUM(stock_hour6_22_cnt) AS stockout_hours,
    SUM(stockout_flag) AS stockout_days,
    ROUND(100.0 * SUM(stockout_flag) / COUNT(*), 4) AS stockout_rate_pct
FROM vw_retail_analysis
GROUP BY store_id, product_id;

SELECT COUNT(*) AS store_product_combinations
FROM vw_store_product_summary;

SELECT
    observations,
    COUNT(*) AS number_of_combinations
FROM vw_store_product_summary
GROUP BY observations
ORDER BY observations;

/* 
   7. INVENTORY PRIORITY SEGMENTATION
  
   Thresholds from Excel EDA:
   High demand: Avg Daily Demand >= 1.061667
   High stock-out: Stock-Out Rate >= 55.5556%
*/

SELECT COUNT(*) AS priority_combinations
FROM vw_store_product_summary
WHERE avg_daily_demand >= 1.061667
  AND stockout_rate_pct >= 55.5556;

SELECT
    store_id,
    product_id,
    avg_daily_demand,
    stockout_hours,
    stockout_days,
    stockout_rate_pct
FROM vw_store_product_summary
WHERE avg_daily_demand >= 1.061667
  AND stockout_rate_pct >= 55.5556
ORDER BY stockout_rate_pct DESC, avg_daily_demand DESC;

WITH classified_products AS
(
    SELECT
        store_id,
        product_id,
        avg_daily_demand,
        stockout_hours,
        stockout_days,
        stockout_rate_pct,
        CASE
            WHEN avg_daily_demand >= 1.061667
             AND stockout_rate_pct >= 55.5556
                THEN 'High Demand / High Stockout'
            WHEN avg_daily_demand >= 1.061667
             AND stockout_rate_pct < 55.5556
                THEN 'High Demand / Low Stockout'
            WHEN avg_daily_demand < 1.061667
             AND stockout_rate_pct >= 55.5556
                THEN 'Low Demand / High Stockout'
            ELSE 'Lower Priority'
        END AS inventory_segment
    FROM vw_store_product_summary
)
SELECT
    inventory_segment,
    COUNT(*) AS combinations
FROM classified_products
GROUP BY inventory_segment
ORDER BY combinations DESC;

SELECT
    store_id,
    product_id,
    ROUND(avg_daily_demand, 2) AS avg_daily_demand,
    stockout_hours,
    stockout_days,
    ROUND(stockout_rate_pct, 1) AS stockout_rate_pct
FROM vw_store_product_summary
WHERE avg_daily_demand >= 1.061667
  AND stockout_rate_pct >= 55.5556
ORDER BY stockout_rate_pct DESC, avg_daily_demand DESC
LIMIT 10;

/* 
   8. PRODUCT 267 DATA-QUALITY INVESTIGATION
*/

SELECT
    store_id,
    product_id,
    COUNT(*) AS observations,
    ROUND(AVG(sale_amount), 3) AS average_demand,
    SUM(stockout_flag) AS stockout_days,
    ROUND(100.0 * SUM(stockout_flag) / COUNT(*), 2) AS stockout_rate_pct,
    SUM(CASE WHEN discount_status = 'Review' THEN 1 ELSE 0 END) AS discount_review_records
FROM vw_retail_analysis
WHERE product_id = 267
GROUP BY store_id, product_id
ORDER BY stockout_rate_pct DESC;



/* 
   QUESTION 1
   Which high-demand store-product combinations experience
   the greatest stock-out pressure?
*/

CREATE OR REPLACE VIEW vw_store_product_summary AS
SELECT
    store_id,
    product_id,
    COUNT(*) AS observations,
    ROUND(SUM(sale_amount), 3) AS total_demand,
    ROUND(AVG(sale_amount), 6) AS avg_daily_demand,
    SUM(stock_hour6_22_cnt) AS stockout_hours,
    SUM(stockout_flag) AS stockout_days,
    ROUND(
        100.0 * SUM(stockout_flag) / COUNT(*),
        4
    ) AS stockout_rate_pct
FROM vw_retail_analysis
GROUP BY
    store_id,
    product_id;


/* 75th-percentile thresholds established during Excel EDA:
   Avg Daily Demand >= 1.061667
   Stock-Out Rate   >= 55.5556%
*/

WITH classified_products AS
(
    SELECT
        store_id,
        product_id,
        avg_daily_demand,
        stockout_hours,
        stockout_days,
        stockout_rate_pct,

        CASE
            WHEN avg_daily_demand >= 1.061667
             AND stockout_rate_pct >= 55.5556
                THEN 'High Demand / High Stockout'

            WHEN avg_daily_demand >= 1.061667
                THEN 'High Demand / Low Stockout'

            WHEN stockout_rate_pct >= 55.5556
                THEN 'Low Demand / High Stockout'

            ELSE 'Lower Priority'
        END AS inventory_segment

    FROM vw_store_product_summary
)

SELECT
    inventory_segment,
    COUNT(*) AS combinations
FROM classified_products
GROUP BY inventory_segment
ORDER BY combinations DESC;


/* Highest-priority Store-Product combinations */
SELECT
    store_id,
    product_id,
    ROUND(avg_daily_demand, 2) AS avg_daily_demand,
    stockout_days,
    ROUND(stockout_rate_pct, 1) AS stockout_rate_pct,
    stockout_hours
FROM vw_store_product_summary
WHERE avg_daily_demand >= 1.061667
  AND stockout_rate_pct >= 55.5556
ORDER BY
    stockout_rate_pct DESC,
    avg_daily_demand DESC
LIMIT 20;


/* Store-level stock-out pressure */
SELECT
    store_id,
    ROUND(AVG(sale_amount), 3) AS average_demand,
    SUM(stockout_flag) AS stockout_observations,
    ROUND(
        100.0 * SUM(stockout_flag) / COUNT(*),
        2
    ) AS stockout_rate_pct,
    SUM(stock_hour6_22_cnt) AS total_stockout_hours
FROM vw_retail_analysis
GROUP BY store_id
ORDER BY stockout_rate_pct DESC;


/* 
   QUESTION 2
   Which cities, stores and product categories have the
   strongest demand?
 */

/* Demand by city */
SELECT
    city_id,
    ROUND(SUM(sale_amount), 3) AS total_demand,
    ROUND(AVG(sale_amount), 3) AS average_demand
FROM vw_retail_analysis
GROUP BY city_id
ORDER BY average_demand DESC;


/* Demand by store */
SELECT
    store_id,
    ROUND(SUM(sale_amount), 3) AS total_demand,
    ROUND(AVG(sale_amount), 3) AS average_demand
FROM vw_retail_analysis
GROUP BY store_id
ORDER BY average_demand DESC;


/* Demand by main product category */
SELECT
    first_category_id,
    ROUND(SUM(sale_amount), 3) AS total_demand,
    ROUND(AVG(sale_amount), 3) AS average_demand
FROM vw_retail_analysis
GROUP BY first_category_id
ORDER BY average_demand DESC;


/*
   QUESTION 3
   Are promotions and discounts associated with higher demand?
*/

/* Promotion vs no promotion */
SELECT
    promotion_type,
    COUNT(*) AS observations,
    ROUND(AVG(sale_amount), 3) AS average_demand
FROM vw_retail_analysis
GROUP BY promotion_type;


/* Promotion behavior by category */
SELECT
    first_category_id,

    ROUND(
        AVG(
            CASE
                WHEN activity_flag = 1 THEN sale_amount
            END
        ),
        3
    ) AS promotion_avg_demand,

    ROUND(
        AVG(
            CASE
                WHEN activity_flag = 0 THEN sale_amount
            END
        ),
        3
    ) AS nonpromotion_avg_demand

FROM vw_retail_analysis
GROUP BY first_category_id
ORDER BY
    promotion_avg_demand - nonpromotion_avg_demand DESC;


/* Discounted vs non-discounted observations
   Excludes discount_status = 'Review'.
*/
SELECT
    discount_status,
    COUNT(*) AS observations,
    ROUND(AVG(sale_amount), 3) AS average_demand
FROM vw_retail_analysis
WHERE discount_status <> 'Review'
GROUP BY discount_status;


/* Percentage difference in average demand */
WITH discount_comparison AS
(
    SELECT
        AVG(
            CASE
                WHEN discount_status = 'Discounted'
                THEN sale_amount
            END
        ) AS discounted_demand,

        AVG(
            CASE
                WHEN discount_status = 'No Discount'
                THEN sale_amount
            END
        ) AS no_discount_demand

    FROM vw_retail_analysis
    WHERE discount_status <> 'Review'
)

SELECT
    ROUND(discounted_demand, 3) AS discounted_avg_demand,
    ROUND(no_discount_demand, 3) AS no_discount_avg_demand,
    ROUND(
        100.0 *
        (discounted_demand - no_discount_demand)
        / no_discount_demand,
        2
    ) AS demand_difference_pct
FROM discount_comparison;


/* Promotion and discount interaction */
SELECT
    promotion_type,
    discount_status,
    COUNT(*) AS observations,
    ROUND(AVG(sale_amount), 3) AS average_demand
FROM vw_retail_analysis
WHERE discount_status <> 'Review'
GROUP BY
    promotion_type,
    discount_status
ORDER BY
    promotion_type,
    discount_status;


/* 
   QUESTION 4
   How does demand change across weekdays, weekends and
   holidays?
*/

/* Day-of-week demand */
SELECT
    day_name,
    ROUND(AVG(sale_amount), 3) AS average_demand,
    ROUND(AVG(stock_hour6_22_cnt), 3) AS average_stockout_hours
FROM vw_retail_analysis
GROUP BY
    day_name,
    DAYOFWEEK(dt)
ORDER BY DAYOFWEEK(dt);


/* Weekend vs weekday */
SELECT
    day_type,
    COUNT(*) AS observations,
    ROUND(AVG(sale_amount), 3) AS average_demand,
    ROUND(AVG(stock_hour6_22_cnt), 3) AS average_stockout_hours
FROM vw_retail_analysis
GROUP BY day_type;


/* Separate weekend and holiday effects */
SELECT
    day_type,
    holiday_type,
    COUNT(*) AS observations,
    ROUND(AVG(sale_amount), 3) AS average_demand,
    ROUND(AVG(stock_hour6_22_cnt), 3) AS average_stockout_hours
FROM vw_retail_analysis
GROUP BY
    day_type,
    holiday_type
ORDER BY
    day_type,
    holiday_type;


/* Weekly demand and stock-out trend
   Partial first and last weeks are excluded.
*/
SELECT
    week_start,
    ROUND(SUM(sale_amount), 3) AS total_demand,
    SUM(stock_hour6_22_cnt) AS total_stockout_hours,
    ROUND(AVG(sale_amount), 3) AS average_demand,
    ROUND(AVG(stock_hour6_22_cnt), 3) AS average_stockout_hours
FROM vw_retail_analysis
WHERE week_start BETWEEN '2024-04-01' AND '2024-06-17'
GROUP BY week_start
ORDER BY week_start;


/* 
   QUESTION 5
   Is temperature associated with changes in product demand?
*/

SELECT
    FLOOR(avg_temperature / 2) * 2 AS temp_band_start,
    FLOOR(avg_temperature / 2) * 2 + 2 AS temp_band_end,
    COUNT(*) AS observations,
    ROUND(AVG(sale_amount), 3) AS average_demand,
    ROUND(AVG(stock_hour6_22_cnt), 3) AS average_stockout_hours,
    ROUND(
        100.0 * SUM(stockout_flag) / COUNT(*),
        2
    ) AS stockout_rate_pct
FROM vw_retail_analysis
GROUP BY FLOOR(avg_temperature / 2) * 2
ORDER BY temp_band_start;


/*
   END OF ANALYSIS SCRIPT
 */
