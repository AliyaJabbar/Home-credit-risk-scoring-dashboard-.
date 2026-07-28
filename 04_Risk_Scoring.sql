-- ============================================
-- STEP 1: Initial risk score (first attempt)
-- ============================================
ALTER TABLE application_train_d ADD risk_score FLOAT;

UPDATE application_train_d 
SET risk_score = 
    (ISNULL(debt_to_income_ratio, 3) * 5) +                    -- higher DTI = more risk
    (CASE WHEN employement_years IS NULL THEN 15                -- unemployed/unknown = high risk
          WHEN employement_years < 1 THEN 10                    -- new job = risky
          WHEN employement_years < 3 THEN 5 
          ELSE 0 END) +
    ((1 - EXT_SOURCE_2) * 20) +                                 -- lower external score = more risk
    ((1 - EXT_SOURCE_3) * 20) +
    (is_employment_anomaly * 10);                               -- flagged anomaly = extra risk

SELECT MIN(risk_score), MAX(risk_score), AVG(risk_score) FROM application_train_d;

-- ============================================
-- STEP 2: Percentile-based risk bands (33rd / 67th)
-- ============================================
SELECT 
    PERCENTILE_CONT(0.33) WITHIN GROUP (ORDER BY risk_score) OVER() AS p33,
    PERCENTILE_CONT(0.67) WITHIN GROUP (ORDER BY risk_score) OVER() AS p67
FROM application_train_d;

ALTER TABLE application_train_d ADD risk_band VARCHAR(10);

UPDATE application_train_d 
SET risk_band = CASE 
    WHEN risk_score <= 35.9375888436953 THEN 'Low'
    WHEN risk_score <= 50.546620458519 THEN 'Medium'
    ELSE 'High'
END;

SELECT risk_band, COUNT(*) AS count_applicants
FROM application_train_d
GROUP BY risk_band;

-- ============================================
-- STEP 3: Validate against actual outcomes (TARGET)
-- ============================================
SELECT 
    risk_band,
    COUNT(*) AS total_applicants,
    SUM(CAST(TARGET AS INT)) AS actual_defaults,
    CAST(SUM(CAST(TARGET AS INT)) AS FLOAT) / COUNT(*) * 100 AS default_rate_pct
FROM application_train_d
GROUP BY risk_band
ORDER BY CASE risk_band WHEN 'Low' THEN 1 WHEN 'Medium' THEN 2 WHEN 'High' THEN 3 END;
-- RESULT: Low 5.34%, Medium 9.74%, High 9.09%  -> WRONG ORDER, formula flawed

-- ============================================
-- STEP 4: Diagnose which features actually predict default
-- ============================================
SELECT 
    CASE WHEN EXT_SOURCE_2 < 0.3 THEN 'Low EXT2'
         WHEN EXT_SOURCE_2 < 0.6 THEN 'Mid EXT2'
         ELSE 'High EXT2' END AS ext2_group,
    COUNT(*) AS total,
    AVG(CAST(TARGET AS FLOAT)) * 100 AS default_rate_pct
FROM application_train_d
GROUP BY CASE WHEN EXT_SOURCE_2 < 0.3 THEN 'Low EXT2'
              WHEN EXT_SOURCE_2 < 0.6 THEN 'Mid EXT2'
              ELSE 'High EXT2' END;
-- Strong, clean predictor: 15.85% -> 8.49% -> 4.56%

SELECT 
    CASE WHEN debt_to_income_ratio < 2 THEN 'Low DTI'
         WHEN debt_to_income_ratio < 5 THEN 'Mid DTI'
         ELSE 'High DTI' END AS dti_group,
    COUNT(*) AS total,
    AVG(CAST(TARGET AS FLOAT)) * 100 AS default_rate_pct
FROM application_train_d
GROUP BY CASE WHEN debt_to_income_ratio < 2 THEN 'Low DTI'
              WHEN debt_to_income_ratio < 5 THEN 'Mid DTI'
              ELSE 'High DTI' END;
-- Weak/no pattern: 7.48% -> 8.73% -> 7.38%

-- ============================================
-- STEP 5: Reweight formula based on evidence
-- ============================================
UPDATE application_train_d 
SET risk_score = 
    (ISNULL(debt_to_income_ratio, 3) * 1) +                    -- weight reduced: 5 -> 1 (weak predictor)
    (CASE WHEN employement_years IS NULL THEN 15                       
          WHEN employement_years < 1 THEN 10                           
          WHEN employement_years < 3 THEN 5 
          ELSE 0 END) +
    ((1 - EXT_SOURCE_2) * 40) +                                 -- weight increased: 20 -> 40 (strong predictor)
    ((1 - EXT_SOURCE_3) * 40) +                                 -- weight increased: 20 -> 40 (strong predictor)
    (is_employment_anomaly * 10);

-- ============================================
-- STEP 6: Recompute bands and re-validate
-- ============================================
SELECT 
    PERCENTILE_CONT(0.33) WITHIN GROUP (ORDER BY risk_score) OVER() AS p33,
    PERCENTILE_CONT(0.67) WITHIN GROUP (ORDER BY risk_score) OVER() AS p67
FROM application_train_d;

UPDATE application_train_d 
SET risk_band = CASE 
    WHEN risk_score <= 41.1140201463165 THEN 'Low'
    WHEN risk_score <= 54.7246625521851 THEN 'Medium'
    ELSE 'High'
END;

SELECT 
    risk_band,
    COUNT(*) AS total_applicants,
    SUM(CAST(TARGET AS INT)) AS actual_defaults,
    CAST(SUM(CAST(TARGET AS INT)) AS FLOAT) / COUNT(*) * 100 AS default_rate_pct
FROM application_train_d
GROUP BY risk_band
ORDER BY CASE risk_band WHEN 'Low' THEN 1 WHEN 'Medium' THEN 2 WHEN 'High' THEN 3 END;
-- RESULT: Low 3.68%, Medium 7.97%, High 12.56%  -> validated, correct order
