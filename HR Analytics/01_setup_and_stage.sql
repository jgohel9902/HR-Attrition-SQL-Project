/* ============================================================
   Project : HR Attrition & Retention Intelligence (SQL Only)
   Author  : Jenil Gohel
   DB      : SQL Server (SSMS)
   Purpose : Stage HR dataset + validate import (foundation step)
   File    : 01_setup_and_stage.sql
============================================================ */

SET NOCOUNT ON;
GO

/* ============================================================
   0) Create / Use Database
============================================================ */

-- Database creation
IF DB_ID('HR_ATTRITION_SQL') IS NULL
BEGIN
    CREATE DATABASE HR_ATTRITION_SQL;
END
GO

-- Use database
USE HR_ATTRITION_SQL;
GO

/* ============================================================
   1) Create Staging Schema (raw landing area)
============================================================ */

IF SCHEMA_ID('stg') IS NULL
BEGIN
    EXEC('CREATE SCHEMA stg');
END
GO

/* ============================================================
   2) Create Staging Table 
   Purpose: Holds the raw dataset exactly as imported
============================================================ */

IF OBJECT_ID('stg.HR_EmployeeAttrition_Raw', 'U') IS NULL
BEGIN
    CREATE TABLE stg.HR_EmployeeAttrition_Raw
    (
        -- Employee demographics
        Age INT,
        Attrition NVARCHAR(20),
        BusinessTravel NVARCHAR(50),
        DailyRate INT,
        Department NVARCHAR(50),
        DistanceFromHome INT,
        Education INT,
        EducationField NVARCHAR(50),
        EmployeeCount INT,
        EmployeeNumber INT,            -- Unique employee id
        EnvironmentSatisfaction INT,
        Gender NVARCHAR(10),
        HourlyRate INT,

        -- Job details
        JobInvolvement INT,
        JobLevel INT,
        JobRole NVARCHAR(50),
        JobSatisfaction INT,
        MaritalStatus NVARCHAR(20),

        -- Compensation
        MonthlyIncome INT,
        MonthlyRate INT,
        PercentSalaryHike INT,
        StockOptionLevel INT,

        -- Experience / history
        NumCompaniesWorked INT,
        TotalWorkingYears INT,
        TrainingTimesLastYear INT,

        -- Work conditions
        Over18 NVARCHAR(5),
        OverTime NVARCHAR(5),
        PerformanceRating INT,
        RelationshipSatisfaction INT,
        StandardHours INT,
        WorkLifeBalance INT,

        -- Tenure
        YearsAtCompany INT,
        YearsInCurrentRole INT,
        YearsSinceLastPromotion INT,
        YearsWithCurrManager INT
    );
END
GO

   /* ======================================
   3) Data Import Note (Manual)
    ===================================== */
IF OBJECT_ID('dbo.[WA_Fn-UseC_-HR-Employee-Attrition]', 'U') IS NOT NULL
BEGIN
    -- Copy only if staging is currently empty (prevents duplicates)
    IF (SELECT COUNT(*) FROM stg.HR_EmployeeAttrition_Raw) = 0
    BEGIN
        INSERT INTO stg.HR_EmployeeAttrition_Raw
        SELECT *
        FROM dbo.[WA_Fn-UseC_-HR-Employee-Attrition];
    END
GO

/* ============================================================
   5) Data Audit (Validation Checks)
============================================================ */

-- 5.1 Row count (expected around ~1470)
SELECT COUNT(*) AS Total_Employees
FROM stg.HR_EmployeeAttrition_Raw;
GO

-- 5.2 Attrition distribution (Yes/No)
SELECT
    Attrition,
    COUNT(*) AS Employee_Count
FROM stg.HR_EmployeeAttrition_Raw
GROUP BY Attrition
ORDER BY Employee_Count DESC;
GO

-- 5.3 Duplicate employee id check
SELECT
    EmployeeNumber,
    COUNT(*) AS Duplicate_Count
FROM stg.HR_EmployeeAttrition_Raw
GROUP BY EmployeeNumber
HAVING COUNT(*) > 1;
GO

-- 5.4 NULL scan for key fields
SELECT
    SUM(CASE WHEN EmployeeNumber IS NULL THEN 1 ELSE 0 END) AS Null_EmployeeNumber,
    SUM(CASE WHEN Department IS NULL THEN 1 ELSE 0 END) AS Null_Department,
    SUM(CASE WHEN JobRole IS NULL THEN 1 ELSE 0 END) AS Null_JobRole,
    SUM(CASE WHEN MonthlyIncome IS NULL THEN 1 ELSE 0 END) AS Null_MonthlyIncome
FROM stg.HR_EmployeeAttrition_Raw;
GO

