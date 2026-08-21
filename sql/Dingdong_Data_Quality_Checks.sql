

/* 
   DINGDONG_DATA_QUALITY_CHECKS
   Database: MySQL
   Client: HeidiSQL
   Study period: 2024-03-28 to 2024-06-25
   Dataset: 89,100 observations
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
   2. DATA VALIDATION
*/

SELECT COUNT(*) AS total_rows
FROM retail_raw;



SELECT
    COUNT(DISTINCT city_id) AS cities,
    COUNT(DISTINCT store_id) AS stores,
    COUNT(DISTINCT product_id) AS products
FROM retail_raw;



SELECT
    MIN(dt) AS start_date,
    MAX(dt) AS end_date,
    COUNT(DISTINCT dt) AS number_of_dates
FROM retail_raw;



SELECT
    store_id,
    product_id,
    dt,
    COUNT(*) AS record_count
FROM retail_raw
GROUP BY store_id, product_id, dt
HAVING COUNT(*) > 1;



SELECT
    SUM(city_id IS NULL) AS city_nulls,
    SUM(store_id IS NULL) AS store_nulls,
    SUM(first_category_id IS NULL) AS first_category_nulls,
    SUM(second_category_id IS NULL) AS second_category_nulls,
    SUM(product_id IS NULL) AS product_nulls,
    SUM(dt IS NULL) AS date_nulls,
    SUM(sale_amount IS NULL) AS sales_nulls,
    SUM(stock_hour6_22_cnt IS NULL) AS stockout_nulls,
    SUM(discount IS NULL) AS discount_nulls,
    SUM(holiday_flag IS NULL) AS holiday_nulls,
    SUM(activity_flag IS NULL) AS activity_nulls,
    SUM(precpt IS NULL) AS precipitation_nulls,
    SUM(avg_temperature IS NULL) AS temperature_nulls,
    SUM(avg_humidity IS NULL) AS humidity_nulls
FROM retail_raw;



SELECT
    ROUND(SUM(sale_amount), 3) AS total_demand,
    ROUND(AVG(sale_amount), 3) AS average_demand,
    SUM(stock_hour6_22_cnt) AS total_stockout_hours
FROM retail_raw;


/*
   END OF DATA VALIDATION
 */

