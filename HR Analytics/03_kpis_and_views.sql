/* ============================================================
   Project : HR Attrition & Retention Intelligence (SQL Only)
   File    : 03_kpis_and_views.sql
   Purpose : Create KPI views + analysis queries for insights
============================================================ */

SET NOCOUNT ON;
GO

USE HR_ATTRITION_SQL;
GO

/* ============================================================
   1) Create analytics schema for reporting views
============================================================ */

IF SCHEMA_ID('rpt') IS NULL
BEGIN
    EXEC('CREATE SCHEMA rpt');
END
GO

/* ============================================================
   2) View: Overall Attrition Summary
   - One row with overall employee count and attrition rate
============================================================ */

CREATE OR ALTER VIEW rpt.v_attrition_overall
AS
SELECT
    COUNT(*) AS total_employees,

    -- Attrition count (Yes)
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS attrition_yes,

    -- Attrition rate %
    CAST(
        100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0)
        AS DECIMAL(5,2)
    ) AS attrition_rate_pct
FROM dw.fact_employee_snapshot;
GO

/* ============================================================
   3) View: Attrition by Department
============================================================ */

CREATE OR ALTER VIEW rpt.v_attrition_by_department
AS
SELECT
    j.Department,
    COUNT(*) AS employees,
    SUM(CASE WHEN f.Attrition = 'Yes' THEN 1 ELSE 0 END) AS attrition_yes,
    CAST(
        100.0 * SUM(CASE WHEN f.Attrition = 'Yes' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0)
        AS DECIMAL(5,2)
    ) AS attrition_rate_pct
FROM dw.fact_employee_snapshot f
JOIN dw.dim_job j
    ON f.job_key = j.job_key
GROUP BY j.Department;
GO

/* ============================================================
   4) View: Attrition by Job Role (within Department)
============================================================ */

CREATE OR ALTER VIEW rpt.v_attrition_by_jobrole
AS
SELECT
    j.Department,
    j.JobRole,
    COUNT(*) AS employees,
    SUM(CASE WHEN f.Attrition = 'Yes' THEN 1 ELSE 0 END) AS attrition_yes,
    CAST(
        100.0 * SUM(CASE WHEN f.Attrition = 'Yes' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0)
        AS DECIMAL(5,2)
    ) AS attrition_rate_pct
FROM dw.fact_employee_snapshot f
JOIN dw.dim_job j
    ON f.job_key = j.job_key
GROUP BY j.Department, j.JobRole;
GO

/* ============================================================
   5) View: Attrition by OverTime (high-impact driver)
============================================================ */

CREATE OR ALTER VIEW rpt.v_attrition_by_overtime
AS
SELECT
    j.OverTime,
    COUNT(*) AS employees,
    SUM(CASE WHEN f.Attrition = 'Yes' THEN 1 ELSE 0 END) AS attrition_yes,
    CAST(
        100.0 * SUM(CASE WHEN f.Attrition = 'Yes' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0)
        AS DECIMAL(5,2)
    ) AS attrition_rate_pct
FROM dw.fact_employee_snapshot f
JOIN dw.dim_job j
    ON f.job_key = j.job_key
GROUP BY j.OverTime;
GO

/* ============================================================
   6) View: Attrition by Tenure Band
   Bands are business-friendly categories for YearsAtCompany
============================================================ */

CREATE OR ALTER VIEW rpt.v_attrition_by_tenure_band
AS
WITH base AS
(
    SELECT
        f.Attrition,
        f.YearsAtCompany,
        CASE
            WHEN f.YearsAtCompany < 1 THEN '<1 year'
            WHEN f.YearsAtCompany BETWEEN 1 AND 2 THEN '1-2 years'
            WHEN f.YearsAtCompany BETWEEN 3 AND 5 THEN '3-5 years'
            WHEN f.YearsAtCompany BETWEEN 6 AND 10 THEN '6-10 years'
            ELSE '10+ years'
        END AS tenure_band
    FROM dw.fact_employee_snapshot f
)
SELECT
    tenure_band,
    COUNT(*) AS employees,
    SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) AS attrition_yes,
    CAST(
        100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0)
        AS DECIMAL(5,2)
    ) AS attrition_rate_pct
FROM base
GROUP BY tenure_band;
GO