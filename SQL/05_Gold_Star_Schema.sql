-- ============================================
-- GOLD LAYER: Star Schema
-- ============================================

-- Dimension: Client
CREATE TABLE dim_client (
    client_key INT IDENTITY(1,1) PRIMARY KEY,
    sk_id_curr INT,
    gender VARCHAR(10),
    age_years INT,
    family_status VARCHAR(50),
    education_type VARCHAR(50),
    occupation_type VARCHAR(50),
    num_children INT,
    employment_years FLOAT,
    is_employment_anomaly INT
);

INSERT INTO dim_client (sk_id_curr, gender, age_years, family_status, education_type, occupation_type, num_children, employment_years, is_employment_anomaly)
SELECT SK_ID_CURR, CODE_GENDER, age_years, NAME_FAMILY_STATUS, NAME_EDUCATION_TYPE, OCCUPATION_TYPE, CNT_CHILDREN, employement_years, is_employment_anomaly
FROM application_train_d;

-- Dimension: Loan Type
CREATE TABLE dim_loan_type (
    loan_type_key INT IDENTITY(1,1) PRIMARY KEY,
    contract_type VARCHAR(50)
);

INSERT INTO dim_loan_type (contract_type)
SELECT DISTINCT NAME_CONTRACT_TYPE FROM application_train_d;

-- Dimension: Risk Band
CREATE TABLE dim_risk_band (
    risk_band_key INT IDENTITY(1,1) PRIMARY KEY,
    risk_band VARCHAR(10),
    risk_band_description VARCHAR(100)
);

INSERT INTO dim_risk_band (risk_band, risk_band_description) VALUES
('Low', 'Bottom 33% by risk score - lowest default likelihood'),
('Medium', 'Middle 33% by risk score - moderate default likelihood'),
('High', 'Top 33% by risk score - highest default likelihood');

-- Fact table
CREATE TABLE fact_loan_application (
    fact_key INT IDENTITY(1,1) PRIMARY KEY,
    sk_id_curr INT,
    client_key INT,
    loan_type_key INT,
    risk_band_key INT,
    amt_income FLOAT,
    amt_credit FLOAT,
    amt_annuity FLOAT,
    debt_to_income_ratio FLOAT,
    credit_annuity_ratio FLOAT,
    risk_score FLOAT,
    is_default INT,
    FOREIGN KEY (client_key) REFERENCES dim_client(client_key),
    FOREIGN KEY (loan_type_key) REFERENCES dim_loan_type(loan_type_key),
    FOREIGN KEY (risk_band_key) REFERENCES dim_risk_band(risk_band_key)
);

INSERT INTO fact_loan_application 
    (sk_id_curr, client_key, loan_type_key, risk_band_key, amt_income, amt_credit, amt_annuity, 
     debt_to_income_ratio, credit_annuity_ratio, risk_score, is_default)
SELECT 
    a.SK_ID_CURR,
    c.client_key,
    lt.loan_type_key,
    rb.risk_band_key,
    a.AMT_INCOME_TOTAL,
    a.AMT_CREDIT,
    a.AMT_ANNUITY,
    a.debt_to_income_ratio,
    a.credit_annuity_ratio,
    a.risk_score,
    CAST(a.TARGET AS INT)
FROM application_train_d a
JOIN dim_client c ON a.SK_ID_CURR = c.sk_id_curr
JOIN dim_loan_type lt ON a.NAME_CONTRACT_TYPE = lt.contract_type
JOIN dim_risk_band rb ON a.risk_band = rb.risk_band;

-- Indexes for join performance
CREATE INDEX idx_fact_client ON fact_loan_application(client_key);
CREATE INDEX idx_fact_loantype ON fact_loan_application(loan_type_key);
CREATE INDEX idx_fact_riskband ON fact_loan_application(risk_band_key);

-- Verification
SELECT COUNT(*) FROM fact_loan_application;  -- expect 307,511

SELECT name, type_desc FROM sys.indexes WHERE object_id = OBJECT_ID('fact_loan_application');

-- Business insight check: does loan type add signal beyond risk score?
SELECT 
    rb.risk_band,
    lt.contract_type,
    COUNT(*) AS total_loans,
    AVG(f.risk_score) AS avg_risk_score,
    SUM(f.is_default) AS actual_defaults
FROM fact_loan_application f
JOIN dim_risk_band rb ON f.risk_band_key = rb.risk_band_key
JOIN dim_loan_type lt ON f.loan_type_key = lt.loan_type_key
GROUP BY rb.risk_band, lt.contract_type
ORDER BY rb.risk_band;
