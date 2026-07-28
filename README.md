# Home-credit-risk-scoring-dashboard
SQL + Power BI risk scoring dashboard for loan default prediction using Medallion architecture
# Home Credit Loan Default Risk Scoring Dashboard

An end-to-end data pipeline and Power BI dashboard that scores loan applicants by default risk, built on the [Home Credit Default Risk](https://www.kaggle.com/c/home-credit-default-risk/data) dataset (~307,511 loan applications).

## Business Problem

Home Credit lends to applicants with little or no formal credit history. Two costly mistakes are possible when approving a loan:
1. Approving a high-risk applicant who defaults (bad debt)
2. Rejecting a low-risk applicant who would have repaid (lost business)

This project builds an **explainable, rule-based risk scoring system** that segments applicants into Low / Medium / High risk bands, giving the credit team, portfolio managers, and business leadership a shared, transparent view of portfolio risk — rather than a black-box ML prediction.

## Architecture

Data flows through a **Medallion (Bronze–Silver–Gold) architecture**, landing in a **Star Schema** for BI consumption.

```
Raw CSV (application_train.csv)
        |
        v
Bronze  -- raw load, no transformation, source-of-truth
        |
        v
Silver  -- cleaned + feature engineered
        |   - DAYS_EMPLOYED anomaly (365243 placeholder) flagged and nulled
        |   - EXT_SOURCE_1 dropped (56% missing)
        |   - EXT_SOURCE_2 / EXT_SOURCE_3 median-imputed
        |   - Engineered: age_years, employment_years,
        |     debt_to_income_ratio, credit_annuity_ratio
        v
Gold    -- Star Schema (SQL Server)
        |   - fact_loan_application (307,511 rows, indexed on FKs)
        |   - dim_client
        |   - dim_loan_type
        |   - dim_risk_band
        v
Power BI -- 4-page interactive dashboard
```

## Data Cleaning Highlights

- **Employment anomaly**: `DAYS_EMPLOYED` contained a placeholder value of 365,243 (≈1,000 years) for unemployed/retired applicants — a known data quality issue in this dataset. These ~55,000 rows were flagged with an `is_employment_anomaly` indicator and the value nulled, rather than treated as a genuine outlier.
- **Missing values**: Handled by relevance rather than a blanket rule — `EXT_SOURCE_1` (56% null) was dropped, while `EXT_SOURCE_2`/`EXT_SOURCE_3` (0.2% and 20% null) were median-imputed to preserve two of the dataset's stronger predictive signals.

## Risk Score & Validation

The risk score is a weighted combination of debt-to-income ratio, employment stability, external credit bureau scores (`EXT_SOURCE_2`, `EXT_SOURCE_3`), and the employment anomaly flag. Applicants are split into Low / Medium / High bands using **percentile-based thresholds** (33rd / 67th percentile), so bands stay balanced regardless of outliers in the raw score.

**The first version of the formula was wrong** — validating risk bands against actual loan outcomes (`TARGET`) showed the Medium band defaulting *more* than the High band. Segment-level analysis showed why: debt-to-income ratio had almost no relationship with actual default (7.5% vs 7.4% across low/high DTI), while `EXT_SOURCE_2` was a strong, clean predictor (15.9% default at low scores vs 4.6% at high scores). The formula was reweighted accordingly — DTI's weight reduced, `EXT_SOURCE` weights increased — and re-validated:

| Risk Band | Applicants | Actual Default Rate |
|---|---|---|
| Low | 101,479 | 3.68% |
| Medium | 104,553 | 7.97% |
| High | 101,479 | 12.56% |

The High-risk band now shows a **3.4x higher default rate** than Low-risk, confirming the score is directionally meaningful, not just an arbitrary formula.

## Dashboard Pages

1. **Executive Overview** — portfolio KPIs (total applications, credit volume, overall default rate), trend and mix visuals
2. **Risk Segmentation** — default rate by risk band (the core validation chart), applicant distribution
3. **Segment Deep-dive** — default rate by education/occupation, debt-to-income vs risk score, interactive filters
4. **Individual / Trend View** — drill-through applicant table, portfolio default rate vs target benchmark

## Tech Stack

- **SQL Server** — Bronze/Silver/Gold pipeline, star schema, indexing
- **T-SQL** — data cleaning, feature engineering, percentile-based banding, validation queries
- **Power BI** — DAX measures, conditional formatting, 4-page interactive dashboard

## Repository Structure

```
sql/
  01_bronze_import.sql
  02_silver_cleaning.sql
  03_feature_engineering.sql
  04_risk_scoring.sql
  05_gold_star_schema.sql
powerbi/
  risk_dashboard.pbix
screenshots/
  (dashboard page images)
README.md
```

## Key Takeaways

- Practiced a real Medallion architecture + star schema, not just a flat CSV-to-chart exercise
- Diagnosed and fixed a flawed scoring formula using actual outcome data rather than assumed weights
- Built an explainable, business-facing risk score instead of a black-box model — matching how a lending risk team would actually want to consume this
