-- Project Name :- Analyzing Customer Retention and Lifetime Value Through Cohort Analysis

--Name: Vijay Kumar
--Email: vijay.kumar_cs22@gla.ac.in


/* 
 The goal of this project is to perform cohort analysis to understand and
  improve customer retention on Gameflix using SQL. Here's how we can approach it:

 1. Data Preparation
 2. Creating Customer Cohorts & Analyzing Customer Retention
 3. Customer Lifetime Value (CLTV)
*/


-- 1. Data Preparation



-- step (1) - Checking for data quality and consistency. 

-- Checking for missing values in the ORDER table
SELECT
    SUM(CASE WHEN o."ORDER_ID" IS NULL THEN 1 ELSE 0 END) AS missing_order_id,
    SUM(CASE WHEN o."USER_ID" IS NULL THEN 1 ELSE 0 END) AS missing_user_id,
    SUM(CASE WHEN o."PROMO_ID" IS NULL THEN 1 ELSE 0 END) AS missing_promo_id,
    SUM(CASE WHEN o."ORDER_DATE" IS NULL THEN 1 ELSE 0 END) AS missing_order_date,
    SUM(CASE WHEN o."ORDER_SEQ" IS NULL THEN 1 ELSE 0 END) AS missing_order_seq,
    SUM(CASE WHEN o."REDEMPTION_DATE" IS NULL THEN 1 ELSE 0 END) AS missing_redemption_date,
    SUM(CASE WHEN o."REDEMPTION_DATE" IS NULL THEN 1 ELSE 0 END) AS missing_validity_till_date,
    SUM(CASE WHEN o."ORDER_STAUS" IS NULL THEN 1 ELSE 0 END) AS missing_order_status
FROM "ORDER" o;
-- zero missing values in the orders table




-- Checking for missing values in the promotional_plan table
SELECT
    SUM(CASE WHEN pp."PROMO_ID" IS NULL THEN 1 ELSE 0 END) AS missing_promo_id,
    SUM(CASE WHEN pp."PROMO_PLAN" IS NULL THEN 1 ELSE 0 END) AS missing_promo_plan,
    SUM(CASE WHEN pp."PROMO_OFFER_TYPE" IS NULL THEN 1 ELSE 0 END) AS missing_promo_offer_type,
    SUM(CASE WHEN pp."SUBSCRIPTION_TYPE" IS NULL THEN 1 ELSE 0 END) AS missing_subscription_type,
    SUM(CASE WHEN pp."BASE PRICE" IS NULL THEN 1 ELSE 0 END) AS missing_base_price,
    SUM(CASE WHEN pp."DISCOUNT_PERCENTAGE" IS NULL THEN 1 ELSE 0 END) AS missing_discount_percentage,
    SUM(CASE WHEN pp."EFFECTIVE_PRICE" IS NULL THEN 1 ELSE 0 END) AS missing_effective_price
FROM promotional_plan pp ;
-- zero missing values in the promotion_plan table





-- Checking for missing values in the user_registration table
select
    SUM(CASE WHEN ur."User Id" IS NULL THEN 1 ELSE 0 END) AS missing_user_id,
    SUM(CASE WHEN ur."Full Name" IS NULL THEN 1 ELSE 0 END) AS missing_full_name,
    SUM(CASE WHEN ur."Age" IS NULL THEN 1 ELSE 0 END) AS missing_age,
    SUM(CASE WHEN ur."Gender" IS NULL THEN 1 ELSE 0 END) AS missing_gender,
    SUM(CASE WHEN ur."Country" IS NULL THEN 1 ELSE 0 END) AS missing_country,
    SUM(CASE WHEN ur."City" IS NULL THEN 1 ELSE 0 END) AS missing_city
FROM user_registration ur ;
-- zero missing values in the user_registration table





-- Checking for duplicate order_id in the ORDER table
SELECT 
    o."ORDER_ID" , 
    COUNT(*) AS count 
FROM "ORDER" o 
GROUP BY o."ORDER_ID" 
HAVING COUNT(*) > 1;
-- zero duplicate values in order table




-- Checking for duplicate promo_id in the promotional_plan table
SELECT 
    pp."PROMO_ID" , 
    COUNT(*) AS count 
FROM promotional_plan pp 
GROUP BY pp."PROMO_ID" 
HAVING COUNT(*) > 1;
--zero duplicate values in promotional_plan table




-- Checking for duplicate user_id in the USER_REGISTRATION table
SELECT 
    ur."User Id" , 
    COUNT(*) AS count 
FROM user_registration ur 
GROUP BY ur."User Id" 
HAVING COUNT(*) > 1;
-- zero duplicate values




-- Checking for promo_id in the ORDER table that do not exist in the promotional_plan table
SELECT DISTINCT o."PROMO_ID" 
FROM "ORDER" o 
WHERE o."PROMO_ID" NOT IN (SELECT pp."PROMO_ID" FROM promotional_plan pp);
--All promo id present in the order is exist in promotional_plan table




-- Checking for user_id in the ORDER table that do not exist in the USER_REGISTRATION table
SELECT DISTINCT o."USER_ID" 
FROM "ORDER" o 
WHERE o."USER_ID" NOT IN (SELECT User Id FROM user_registration ur);
-- user id are missing in the orders table 
-- we can  adjust by excluding records with missing user_id to ensure data consistency.




-- step (2) - Extracting  Required Fields

ALTER TABLE "ORDER" ADD COLUMN active_month DATE;
UPDATE "ORDER" o 
SET active_month = DATE_TRUNC('month', o."ORDER_DATE"::timestamp);

ALTER TABLE "ORDER" ADD COLUMN promo_activation_month DATE;
UPDATE "ORDER" o 
SET promo_activation_month = DATE_TRUNC('month', TO_TIMESTAMP(o."REDEMPTION_DATE", 'DD-MM-YYYY'));

ALTER TABLE "ORDER" ADD COLUMN promo_ending_month DATE;
UPDATE "ORDER" o 
SET promo_ending_month = DATE_TRUNC('month', o."VALIDITY_TILL_DATE"::DATE);


-- 2. Creating Customer Cohorts & Analyzing Customer Retention

-- Creating cohorts based on the month of first subscription
WITH user_cohorts AS (
    SELECT 
        o."USER_ID",
        DATE_TRUNC('month', MIN(TO_DATE(o."ORDER_DATE", 'DD-MM-YYYY'))) AS cohort_month
    FROM "ORDER" o 
    GROUP BY o."USER_ID"
)




-- Calculating the number of users retained in each subsequent month
, cohort_retention AS (
    SELECT 
        uc.cohort_month,
        DATE_TRUNC('month', TO_DATE(o2."ORDER_DATE", 'DD-MM-YYYY')) AS active_month,
        COUNT(DISTINCT o2."USER_ID") AS retained_users
    FROM user_cohorts uc
    JOIN "ORDER" o2 ON uc."USER_ID" = o2."USER_ID"
    GROUP BY uc.cohort_month, DATE_TRUNC('month', TO_DATE(o2."ORDER_DATE", 'DD-MM-YYYY'))
    ORDER BY uc.cohort_month, active_month
)



-- Calculating retention rates
SELECT 
    TO_CHAR(cr.cohort_month, 'YYYY-MM') AS cohort_month,
    TO_CHAR(cr.active_month, 'YYYY-MM') AS active_month,
    cr.retained_users,
    (cr.retained_users * 1.0 / cohort_size.cohort_count) AS retention_rate
FROM cohort_retention cr
JOIN (
    SELECT 
        cohort_month,
        COUNT("USER_ID") AS cohort_count
    FROM user_cohorts
    GROUP BY cohort_month
) AS cohort_size ON cr.cohort_month = cohort_size.cohort_month
ORDER BY cr.cohort_month, cr.active_month;


-- 3. Customer Lifetime Value (CLTV)

-- step (1) - Calculating Total Revenue Generated by Each Cohort

-- Calculating monthly revenue generated by each cohort over its lifetime
WITH user_cohorts AS (
    SELECT 
        o."USER_ID",
        DATE_TRUNC('month', MIN(o."ORDER_DATE"::DATE)) AS cohort_month
    FROM "ORDER" o
    GROUP BY o."USER_ID"
),




-- Calculating total cohort revenue and average revenue per customer
cohort_revenue AS (
    SELECT 
        uc.cohort_month,
        DATE_TRUNC('month', o."ORDER_DATE"::DATE) AS revenue_month,
        SUM(pp."EFFECTIVE_PRICE") AS monthly_revenue
    FROM user_cohorts uc
    JOIN "ORDER" o ON uc."USER_ID" = o."USER_ID"
    JOIN promotional_plan pp ON o."PROMO_ID" = pp."PROMO_ID"
    GROUP BY uc.cohort_month, DATE_TRUNC('month', o."ORDER_DATE"::DATE)
)



-- Calculating total cohort revenue and average revenue per customer
SELECT 
    cr.cohort_month,
    SUM(cr.monthly_revenue) AS total_cohort_revenue,
    (SUM(cr.monthly_revenue) * 1.0 / cohort_size.cohort_count) AS avg_revenue_per_customer
FROM cohort_revenue cr
JOIN (
    SELECT 
        cohort_month,
        COUNT("USER_ID") AS cohort_count
    FROM user_cohorts
    GROUP BY cohort_month
) AS cohort_size ON cr.cohort_month = cohort_size.cohort_month
GROUP BY cr.cohort_month, cohort_size.cohort_count
ORDER BY cr.cohort_month;



-- step (3) - Calculating Gross Margin

-- Step 1: Defining User Cohorts based on the month of first subscription
WITH user_cohorts AS (
    SELECT 
        o."USER_ID",
        DATE_TRUNC('month', MIN(o."ORDER_DATE"::DATE)) AS cohort_month
    FROM "ORDER" o
    GROUP BY o."USER_ID"
),



-- Step 2: Calculating monthly revenue for each cohort
cohort_revenue AS (
    SELECT 
        uc.cohort_month,
        DATE_TRUNC('month', o."ORDER_DATE"::DATE) AS revenue_month,
        SUM(pp."EFFECTIVE_PRICE") AS monthly_revenue
    FROM user_cohorts uc
    JOIN "ORDER" o ON uc."USER_ID" = o."USER_ID"
    JOIN promotional_plan pp ON o."PROMO_ID" = pp."PROMO_ID"
    GROUP BY uc.cohort_month, DATE_TRUNC('month', o."ORDER_DATE"::DATE)
),



-- Step 3: Aggregating cohort revenue and calculating average revenue per customer
cohort_revenue_analysis AS (
    SELECT 
        cr.cohort_month,
        SUM(cr.monthly_revenue) AS total_cohort_revenue,
        (SUM(cr.monthly_revenue) * 1.0 / cohort_size.cohort_count) AS avg_revenue_per_customer
    FROM cohort_revenue cr
    JOIN (
        SELECT 
            cohort_month,
            COUNT("USER_ID") AS cohort_count
        FROM user_cohorts
        GROUP BY cohort_month
    ) AS cohort_size ON cr.cohort_month = cohort_size.cohort_month
    GROUP BY cr.cohort_month, cohort_size.cohort_count
)



-- Step 4: Calculating CLTV with gross margin
SELECT 
    TO_CHAR(cohort_month, 'YYYY-MM') AS cohort_month,  
    total_cohort_revenue,
    avg_revenue_per_customer,
    (total_cohort_revenue * 0.65) AS cltv_with_gross_margin  -- Calculating CLTV with gross margin
FROM cohort_revenue_analysis
ORDER BY cohort_month;
