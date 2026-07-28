-- Employment years
ALTER TABLE application_train_d ADD employement_years FLOAT;
UPDATE application_train_d
SET employement_years = CASE 
    WHEN DAYS_EMPLOYED IS NULL THEN NULL 
    ELSE ABS(DAYS_EMPLOYED) / 365.0 
END;

-- Debt-to-Income Ratio
ALTER TABLE application_train_d ADD debt_to_income_ratio FLOAT;
UPDATE application_train_d 
SET debt_to_income_ratio = CASE 
    WHEN AMT_INCOME_TOTAL > 0 THEN AMT_CREDIT / AMT_INCOME_TOTAL 
    ELSE NULL 
END;

-- Credit-to-Annuity Ratio
ALTER TABLE application_train_d ADD credit_annuity_ratio FLOAT;
UPDATE application_train_d 
SET credit_annuity_ratio = CASE 
    WHEN AMT_ANNUITY > 0 THEN AMT_CREDIT / AMT_ANNUITY 
    ELSE NULL 
END;

SELECT TOP 5 age_years, employement_years, debt_to_income_ratio, credit_annuity_ratio 
FROM application_train_d;
