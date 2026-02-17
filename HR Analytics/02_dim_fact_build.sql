/* ============================================================
   Project : HR Attrition & Retention Intelligence (SQL Only)
   File    : 02_dim_fact_build.sql
   Purpose : Build clean Dim/Fact model from staging table
============================================================ */

SET NOCOUNT ON;
GO

USE HR_ATTRITION_SQL;
GO

/* ============================================================
   1) Create warehouse schema
============================================================ */

IF SCHEMA_ID('dw') IS NULL
BEGIN
    EXEC('CREATE SCHEMA dw');
END
GO

/* ============================================================
   2) Drop tables 
============================================================ */

IF OBJECT_ID('dw.fact_employee_snapshot', 'U') IS NOT NULL DROP TABLE dw.fact_employee_snapshot;
IF OBJECT_ID('dw.dim_employee', 'U') IS NOT NULL DROP TABLE dw.dim_employee;
IF OBJECT_ID('dw.dim_job', 'U') IS NOT NULL DROP TABLE dw.dim_job;
GO

/* ============================================================
   3) Create Dimension Tables
============================================================ */

-- 3.1 Job/Org dimension (department + role + travel + etc.)
CREATE TABLE dw.dim_job
(
    job_key INT IDENTITY(1,1) PRIMARY KEY,

    -- Org / role attributes
    Department NVARCHAR(50) NOT NULL,
    JobRole NVARCHAR(50) NOT NULL,
    JobLevel INT NOT NULL,

    -- Work conditions that affect attrition
    BusinessTravel NVARCHAR(50) NOT NULL,
    OverTime NVARCHAR(5) NOT NULL,

    -- Optional: keep common descriptive attributes
    EducationField NVARCHAR(50) NULL
);
GO

-- 3.2 Employee dimension (stable-ish attributes)
CREATE TABLE dw.dim_employee
(
    employee_key INT IDENTITY(1,1) PRIMARY KEY,

    -- Natural key from dataset
    EmployeeNumber INT NOT NULL UNIQUE,

    -- Demographics
    Age INT NOT NULL,
    Gender NVARCHAR(10) NOT NULL,
    MaritalStatus NVARCHAR(20) NOT NULL,
    DistanceFromHome INT NOT NULL,
    Education INT NOT NULL,

    -- Experience background
    NumCompaniesWorked INT NOT NULL,
    TotalWorkingYears INT NOT NULL
);
GO

/* ============================================================
   4) Create Fact Table
   One row per employee "snapshot" from dataset
============================================================ */

CREATE TABLE dw.fact_employee_snapshot
(
    snapshot_id INT IDENTITY(1,1) PRIMARY KEY,

    -- Keys
    employee_key INT NOT NULL,
    job_key INT NOT NULL,

    -- Outcomes / labels
    Attrition NVARCHAR(20) NOT NULL,  -- Yes/No

    -- Satisfaction metrics
    EnvironmentSatisfaction INT NOT NULL,
    JobInvolvement INT NOT NULL,
    JobSatisfaction INT NOT NULL,
    RelationshipSatisfaction INT NOT NULL,
    WorkLifeBalance INT NOT NULL,

    -- Compensation metrics
    MonthlyIncome INT NOT NULL,
    DailyRate INT NOT NULL,
    HourlyRate INT NOT NULL,
    MonthlyRate INT NOT NULL,
    PercentSalaryHike INT NOT NULL,
    StockOptionLevel INT NOT NULL,

    -- Performance / training
    PerformanceRating INT NOT NULL,
    TrainingTimesLastYear INT NOT NULL,

    -- Tenure metrics
    YearsAtCompany INT NOT NULL,
    YearsInCurrentRole INT NOT NULL,
    YearsSinceLastPromotion INT NOT NULL,
    YearsWithCurrManager INT NOT NULL,

    -- Data quality / constants (kept for completeness)
    StandardHours INT NULL,

    -- Foreign Keys
    CONSTRAINT FK_fact_employee FOREIGN KEY (employee_key) REFERENCES dw.dim_employee(employee_key),
    CONSTRAINT FK_fact_job      FOREIGN KEY (job_key) REFERENCES dw.dim_job(job_key)
);
GO

/* ============================================================
   5) Load Dimensions (deduplicate from staging)
============================================================ */

-- 5.1 Load dim_job (distinct combinations)
INSERT INTO dw.dim_job (Department, JobRole, JobLevel, BusinessTravel, OverTime, EducationField)
SELECT DISTINCT
    LTRIM(RTRIM(Department))      AS Department,
    LTRIM(RTRIM(JobRole))         AS JobRole,
    JobLevel,
    LTRIM(RTRIM(BusinessTravel))  AS BusinessTravel,
    LTRIM(RTRIM(OverTime))        AS OverTime,
    NULLIF(LTRIM(RTRIM(EducationField)), '') AS EducationField
FROM stg.HR_EmployeeAttrition_Raw;
GO

-- 5.2 Load dim_employee (one per EmployeeNumber)
INSERT INTO dw.dim_employee
(
    EmployeeNumber, Age, Gender, MaritalStatus, DistanceFromHome, Education,
    NumCompaniesWorked, TotalWorkingYears
)
SELECT
    EmployeeNumber,
    Age,
    LTRIM(RTRIM(Gender))        AS Gender,
    LTRIM(RTRIM(MaritalStatus)) AS MaritalStatus,
    DistanceFromHome,
    Education,
    NumCompaniesWorked,
    TotalWorkingYears
FROM stg.HR_EmployeeAttrition_Raw;
GO

/* ============================================================
   6) Load Fact (join staging to dimensions)
============================================================ */

INSERT INTO dw.fact_employee_snapshot
(
    employee_key, job_key, Attrition,
    EnvironmentSatisfaction, JobInvolvement, JobSatisfaction, RelationshipSatisfaction, WorkLifeBalance,
    MonthlyIncome, DailyRate, HourlyRate, MonthlyRate, PercentSalaryHike, StockOptionLevel,
    PerformanceRating, TrainingTimesLastYear,
    YearsAtCompany, YearsInCurrentRole, YearsSinceLastPromotion, YearsWithCurrManager,
    StandardHours
)
SELECT
    e.employee_key,
    j.job_key,
    LTRIM(RTRIM(s.Attrition)) AS Attrition,

    s.EnvironmentSatisfaction,
    s.JobInvolvement,
    s.JobSatisfaction,
    s.RelationshipSatisfaction,
    s.WorkLifeBalance,

    s.MonthlyIncome,
    s.DailyRate,
    s.HourlyRate,
    s.MonthlyRate,
    s.PercentSalaryHike,
    s.StockOptionLevel,

    s.PerformanceRating,
    s.TrainingTimesLastYear,

    s.YearsAtCompany,
    s.YearsInCurrentRole,
    s.YearsSinceLastPromotion,
    s.YearsWithCurrManager,

    s.StandardHours
FROM stg.HR_EmployeeAttrition_Raw s
JOIN dw.dim_employee e
    ON e.EmployeeNumber = s.EmployeeNumber
JOIN dw.dim_job j
    ON j.Department      = LTRIM(RTRIM(s.Department))
   AND j.JobRole         = LTRIM(RTRIM(s.JobRole))
   AND j.JobLevel        = s.JobLevel
   AND j.BusinessTravel  = LTRIM(RTRIM(s.BusinessTravel))
   AND j.OverTime        = LTRIM(RTRIM(s.OverTime))
   AND (j.EducationField = NULLIF(LTRIM(RTRIM(s.EducationField)), '') OR (j.EducationField IS NULL AND NULLIF(LTRIM(RTRIM(s.EducationField)), '') IS NULL));
GO

/* ============================================================
   7) Validation checks (must run)
============================================================ */

-- Row counts should match expectations
SELECT 'dim_employee' AS table_name, COUNT(*) AS rows FROM dw.dim_employee
UNION ALL
SELECT 'dim_job', COUNT(*) FROM dw.dim_job
UNION ALL
SELECT 'fact_employee_snapshot', COUNT(*) FROM dw.fact_employee_snapshot;
GO

-- Quick sanity: attrition distribution from fact
SELECT Attrition, COUNT(*) AS employees
FROM dw.fact_employee_snapshot
GROUP BY Attrition
ORDER BY employees DESC;
GO