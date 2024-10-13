-- Project Name :- Resolve Issues with Consignment Measurements During Pickup

--Name: Vijay Kumar
--Email: vijay.kumar_cs22@gla.ac.in



--STEP-1: Data Pre-Processing



--task-1: Convert Dimensions to a Common Unit (e.g., centimeters):
-- Check for records with dimensions in inches
SELECT * FROM consignment_volume WHERE unit = 'inches';

-- Convert dimensions from inches to centimeters
UPDATE consignment_volume
SET length = length * 2.54, 
    breadth = breadth * 2.54, 
    height = height * 2.54
WHERE unit = 'inches';




--task-2: Calculate Volume (Cubic Feet):
-- Add a new column for volume in cubic feet
ALTER TABLE consignment_volume ADD COLUMN volume_cft DECIMAL(10, 2);

-- Calculate volume in cubic feet (1 cubic foot = 30.48 cm)
UPDATE consignment_volume
SET volume_cft = (length / 30.48) * (breadth / 30.48) * (height / 30.48);




--task-3: Join Tables to Add Volume to consignment_data
-- Verify column names in consignment_volume for clarity
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'consignment_volume';

-- Retrieve relevant data by joining tables
SELECT cd.id, 
       cd.client_id, 
       cd.weight, 
       cd.total_boxes, 
       cv.volume_cft, 
       cd.industry_type
FROM consignment_data cd
JOIN consignment_volume cv ON cd.id = cv.consignment_id;





--task-4: Calculate Density (kg/CFT):
-- Add a new column for density
ALTER TABLE consignment_data ADD COLUMN density DECIMAL(10, 2);

-- Calculate density as weight (kg) per cubic feet (CFT)
UPDATE consignment_data cd
JOIN consignment_volume cv ON cd.id = cv.consignment_id
SET cd.density = cd.weight / cv.volume_cft
WHERE cv.volume_cft > 0;  -- Ensure no division by zero





--STEP-2: Exploring Data & CFT Analysis



--Industry-Level Statistics:
-- Calculate average, maximum, median CFT and average density by industry
SELECT cd.industry_type,
       AVG(cv.volume_cft) AS avg_cft,
       MAX(cv.volume_cft) AS max_cft,
       PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY cv.volume_cft) AS median_cft,
       AVG(cd.density) AS avg_density
FROM consignment_data cd
JOIN consignment_volume cv ON cd.id = cv.consignment_id
GROUP BY cd.industry_type;





--Client-Level CFT Analysis:
-- Calculate average and maximum CFT by client
SELECT cd.client_id,
       AVG(cv.volume_cft) AS avg_cft,
       MAX(cv.volume_cft) AS max_cft
FROM consignment_data cd
JOIN consignment_volume cv ON cd.id = cv.consignment_id
GROUP BY cd.client_id;






--STEP-3: Outlier Detection Using IQR 


--Calculate IQR for CFT by Industry:
-- Calculate Q1, Q3, and IQR for CFT by industry
WITH cft_percentiles AS (
    SELECT cd.industry_type,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY cv.volume_cft) AS Q1,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY cv.volume_cft) AS Q3
    FROM consignment_data cd
    JOIN consignment_volume cv ON cd.id = cv.consignment_id
    GROUP BY cd.industry_type
)
SELECT industry_type,
       Q1, 
       Q3,
       (Q3 - Q1) AS IQR,
       Q1 - 1.5 * (Q3 - Q1) AS lower_bound,
       Q3 + 1.5 * (Q3 - Q1) AS upper_bound
FROM cft_percentiles;





--Flag Outliers Based on IQR:
-- Flag outliers based on IQR calculations
WITH outlier_limits AS (
    SELECT industry_type,
           Q1 - 1.5 * (Q3 - Q1) AS lower_bound,
           Q3 + 1.5 * (Q3 - Q1) AS upper_bound
    FROM (
        SELECT industry_type,
               PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY cv.volume_cft) AS Q1,
               PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY cv.volume_cft) AS Q3
        FROM consignment_data cd
        JOIN consignment_volume cv ON cd.id = cv.consignment_id
        GROUP BY cd.industry_type
    ) cft_percentiles
)
SELECT cd.id, 
       cd.client_id, 
       cv.volume_cft,
       CASE
           WHEN cv.volume_cft < o.lower_bound OR cv.volume_cft > o.upper_bound THEN 1
           ELSE 0
       END AS flag_outlier
FROM consignment_data cd
JOIN consignment_volume cv ON cd.id = cv.consignment_id
JOIN outlier_limits o ON cd.industry_type = o.industry_type;




--STEP-4: Logic Building for Anomalies


--Logic 1: Weight vs Volume Mismatch:
-- Logic to detect weight vs volume mismatches
SELECT cd.id, 
       cd.client_id, 
       cd.weight, 
       cv.volume_cft,
       CASE
           WHEN ABS(cd.weight - (cv.volume_cft * 7)) > threshold THEN 1 -- Adjust the threshold based on your data analysis
           ELSE 0
       END AS flag_weight_volume_mismatch
FROM consignment_data cd
JOIN consignment_volume cv ON cd.id = cv.consignment_id;



--Logic 2: Density Outliers:
-- Logic to detect density outliers
SELECT cd.id, 
       cd.client_id, 
       cd.density,
       CASE
           WHEN cd.density < lower_density_limit OR cd.density > upper_density_limit THEN 1
           ELSE 0
       END AS flag_density_outlier
FROM consignment_data cd;




--Performance Evaluation:
-- Count total flagged outliers based on both logics
SELECT COUNT(*) AS total_outliers
FROM consignment_data
WHERE flag_weight_volume_mismatch = 1 OR flag_density_outlier = 1;
