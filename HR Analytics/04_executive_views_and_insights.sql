/* ============================================================
   Project : HR Attrition & Retention Intelligence (SQL Only)
   File    : 04_executive_views_and_insights.sql
   Purpose : Final reporting layer (executive summary + drivers)
============================================================ */

SET NOCOUNT ON;
GO

USE HR_ATTRITION_SQL;
GO

/* ============================================================
   1) Ensure reporting schema exists
============================================================ */
IF SCHEMA_ID('rpt') IS NULL
BEGIN
    EXEC('CREATE SCHEMA rpt');
END
GO

/* ============================================================
   2) Executive Summary View
   - Single row: headcount, attrition, rate, avg income, etc.
============================================================ */
CREATE OR ALTER VIEW rpt.v_executive_summary
AS
SELECT
    COUNT(*) AS total_employees,
    SUM(CASE WHEN f.Attrition = 'Yes' THEN 1 ELSE 0 END) AS attrition_yes,
    CAST(100.0 * SUM(CASE WHEN f.Attrition = 'Yes' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS attrition_rate_pct,

    -- Useful executive context
    CAST(AVG(CAST(f.MonthlyIncome AS DECIMAL(12,2))) AS DECIMAL(12,2)) AS avg_monthly_income,
    CAST(AVG(CAST(f.YearsAtCompany AS DECIMAL(12,2))) AS DECIMAL(12,2)) AS avg_years_at_company,
    CAST(AVG(CAST(f.WorkLifeBalance AS DECIMAL(12,2))) AS DECIMAL(12,2)) AS avg_worklife_balance,
    CAST(AVG(CAST(f.JobSatisfaction AS DECIMAL(12,2))) AS DECIMAL(12,2)) AS avg_job_satisfaction
FROM dw.fact_employee_snapshot f;
GO

/* ============================================================
   3) Key Driver View: Attrition by Department + Role (min size)
   - Filters tiny groups to avoid misleading rates
============================================================ */
CREATE OR ALTER VIEW rpt.v_key_driver_department_role
AS
SELECT
    j.Department,
    j.JobRole,
    COUNT(*) AS employees,
    SUM(CASE WHEN f.Attrition = 'Yes' THEN 1 ELSE 0 END) AS attrition_yes,
    CAST(100.0 * SUM(CASE WHEN f.Attrition = 'Yes' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS attrition_rate_pct
FROM dw.fact_employee_snapshot f
JOIN dw.dim_job j
    ON f.job_key = j.job_key
GROUP BY j.Department, j.JobRole
HAVING COUNT(*) >= 15;   -- keep only meaningful segment sizes
GO

/* ============================================================
   4) Key Driver View: Overtime impact
============================================================ */
CREATE OR ALTER VIEW rpt.v_key_driver_overtime
AS
SELECT
    j.OverTime,
    COUNT(*) AS employees,
    SUM(CASE WHEN f.Attrition = 'Yes' THEN 1 ELSE 0 END) AS attrition_yes,
    CAST(100.0 * SUM(CASE WHEN f.Attrition = 'Yes' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS attrition_rate_pct,

    -- add context: avg satisfaction / balance for that segment
    CAST(AVG(CAST(f.JobSatisfaction AS DECIMAL(10,2))) AS DECIMAL(10,2)) AS avg_job_satisfaction,
    CAST(AVG(CAST(f.WorkLifeBalance AS DECIMAL(10,2))) AS DECIMAL(10,2)) AS avg_worklife_balance
FROM dw.fact_employee_snapshot f
JOIN dw.dim_job j
    ON f.job_key = j.job_key
GROUP BY j.OverTime;
GO

/* ============================================================
   5) Key Driver View: Tenure Band impact
============================================================ */
CREATE OR ALTER VIEW rpt.v_key_driver_tenure_band
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
    CAST(100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS attrition_rate_pct
FROM base
GROUP BY tenure_band;
GO

/* ============================================================
   6) Risk Segments View (rule-based, explainable)
   - Groups employees into High/Medium/Low risk segments
   - Focus on current employees (Attrition = No)
============================================================ */
CREATE OR ALTER VIEW rpt.v_risk_segments_current_employees
AS
WITH scored AS
(
    SELECT
        e.EmployeeNumber,
        j.Department,
        j.JobRole,
        j.OverTime,
        j.BusinessTravel,
        f.YearsAtCompany,
        f.MonthlyIncome,
        f.JobSatisfaction,
        f.WorkLifeBalance,
        f.EnvironmentSatisfaction,

        /* Explainable scoring */
        (CASE WHEN j.OverTime = 'Yes' THEN 30 ELSE 0 END) +
        (CASE WHEN f.JobSatisfaction IN (1,2) THEN 20 ELSE 0 END) +
        (CASE WHEN f.WorkLifeBalance IN (1,2) THEN 20 ELSE 0 END) +
        (CASE WHEN f.EnvironmentSatisfaction IN (1,2) THEN 10 ELSE 0 END) +
        (CASE WHEN f.YearsAtCompany < 2 THEN 10 ELSE 0 END) AS risk_score
    FROM dw.fact_employee_snapshot f
    JOIN dw.dim_employee e ON f.employee_key = e.employee_key
    JOIN dw.dim_job j ON f.job_key = j.job_key
    WHERE f.Attrition = 'No'
),
bucketed AS
(
    SELECT
        *,
        CASE
            WHEN risk_score >= 60 THEN 'High'
            WHEN risk_score BETWEEN 30 AND 59 THEN 'Medium'
            ELSE 'Low'
        END AS risk_bucket
    FROM scored
)
SELECT
    risk_bucket,
    COUNT(*) AS employees,
    CAST(AVG(CAST(risk_score AS DECIMAL(10,2))) AS DECIMAL(10,2)) AS avg_risk_score,
    CAST(AVG(CAST(MonthlyIncome AS DECIMAL(12,2))) AS DECIMAL(12,2)) AS avg_monthly_income,
    CAST(AVG(CAST(YearsAtCompany AS DECIMAL(10,2))) AS DECIMAL(10,2)) AS avg_years_at_company
FROM bucketed
GROUP BY risk_bucket;
GO

/* ============================================================
   7) “Top High-Risk Employees” view (for action list)
============================================================ */
CREATE OR ALTER VIEW rpt.v_top_high_risk_employees
AS
WITH scored AS
(
    SELECT
        e.EmployeeNumber,
        j.Department,
        j.JobRole,
        j.OverTime,
        f.YearsAtCompany,
        f.MonthlyIncome,
        f.JobSatisfaction,
        f.WorkLifeBalance,
        (CASE WHEN j.OverTime = 'Yes' THEN 30 ELSE 0 END) +
        (CASE WHEN f.JobSatisfaction IN (1,2) THEN 20 ELSE 0 END) +
        (CASE WHEN f.WorkLifeBalance IN (1,2) THEN 20 ELSE 0 END) +
        (CASE WHEN f.YearsAtCompany < 2 THEN 10 ELSE 0 END) AS risk_score
    FROM dw.fact_employee_snapshot f
    JOIN dw.dim_employee e ON f.employee_key = e.employee_key
    JOIN dw.dim_job j ON f.job_key = j.job_key
    WHERE f.Attrition = 'No'
)
SELECT TOP 25
    EmployeeNumber,
    Department,
    JobRole,
    OverTime,
    YearsAtCompany,
    MonthlyIncome,
    JobSatisfaction,
    WorkLifeBalance,
    risk_score,
    DENSE_RANK() OVER (ORDER BY risk_score DESC) AS risk_rank
FROM scored
ORDER BY risk_score DESC, MonthlyIncome ASC;
GO

SELECT * FROM rpt.v_executive_summary


SELECT TOP 10 * 
FROM rpt.v_key_driver_department_role
ORDER BY attrition_rate_pct DESC, employees DESC;

SELECT * FROM rpt.v_key_driver_overtime
ORDER BY attrition_rate_pct DESC;

SELECT * FROM rpt.v_key_driver_tenure_band
ORDER BY employees DESC;

