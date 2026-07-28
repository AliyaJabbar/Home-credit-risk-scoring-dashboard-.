-- Verify import
SELECT COUNT(*) AS total_rows FROM application_train_d;
SELECT COUNT(*) AS default_case FROM application_train_d WHERE TARGET = 1;

-- Null counts in key columns
SELECT 
    SUM(CASE WHEN AMT_INCOME_TOTAL IS NULL THEN 1 ELSE 0 END) AS null_income,
    SUM(CASE WHEN AMT_CREDIT IS NULL THEN 1 ELSE 0 END) AS null_credit,
    SUM(CASE WHEN DAYS_EMPLOYED IS NULL THEN 1 ELSE 0 END) AS null_employed,
    SUM(CASE WHEN EXT_SOURCE_1 IS NULL THEN 1 ELSE 0 END) AS null_ext1,
    SUM(CASE WHEN EXT_SOURCE_2 IS NULL THEN 1 ELSE 0 END) AS null_ext2,
    SUM(CASE WHEN EXT_SOURCE_3 IS NULL THEN 1 ELSE 0 END) AS null_ext3
FROM application_train_d;

-- DAYS_EMPLOYED anomaly check
SELECT MIN(DAYS_EMPLOYED) AS min_val, MAX(DAYS_EMPLOYED) AS max_val FROM application_train_d;
SELECT COUNT(*) FROM application_train_d WHERE DAYS_EMPLOYED = 365243;

-- Flag and clean the anomaly (365243 = placeholder for unemployed/retired)
ALTER TABLE application_train_d ADD is_employment_anomaly INT;

UPDATE application_train_d 
SET is_employment_anomaly = CASE WHEN DAYS_EMPLOYED = 365243 THEN 1 ELSE 0 END;

UPDATE application_train_d 
SET DAYS_EMPLOYED = NULL 
WHERE DAYS_EMPLOYED = 365243;

-- Verify cleanup
SELECT COUNT(*) AS anomaly_count FROM application_train_d WHERE DAYS_EMPLOYED > 300000;
SELECT is_employment_anomaly, COUNT(*) FROM application_train_d GROUP BY is_employment_anomaly;

-- Drop EXT_SOURCE_1 (56% missing)
ALTER TABLE application_train_d DROP COLUMN EXT_SOURCE_1;

-- Median impute EXT_SOURCE_2 and EXT_SOURCE_3
SELECT 
    (SELECT DISTINCT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXT_SOURCE_2) OVER() 
     FROM application_train_d) AS median_ext2,
    (SELECT DISTINCT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXT_SOURCE_3) OVER() 
     FROM application_train_d) AS median_ext3;

UPDATE application_train_d 
SET EXT_SOURCE_2 = 0.565993666648865 
WHERE EXT_SOURCE_2 IS NULL;

UPDATE application_train_d 
SET EXT_SOURCE_3 = 0.535276234149933 
WHERE EXT_SOURCE_3 IS NULL;

-- Verify no nulls remain
SELECT 
    SUM(CASE WHEN EXT_SOURCE_2 IS NULL THEN 1 ELSE 0 END) AS null_ext2,
    SUM(CASE WHEN EXT_SOURCE_3 IS NULL THEN 1 ELSE 0 END) AS null_ext3
FROM application_train_d;
