## 📊 HR Attrition & Retention Intelligence (SQL Server Project)

🔎 Project Overview
This project analyzes employee attrition patterns using SQL Server and a structured dimensional data model.

The objective was to identify:
- Overall attrition rate
- Department & job role risk patterns
-Overtime impact on attrition
- Tenure-related attrition trends
- High-risk current employees (rule-based scoring)

The solution was built using a professional data warehouse approach (Staging → Dimensions → Fact → Reporting Views).

## 🛠️ Tech Stack

- SQL Server (SSMS)
- T-SQL
- Dimensional Modeling (Star Schema)
- Window Functions
- CTEs
- Reporting Views
- Rule-based Risk Scoring

## 🗂️ Project Architecture

1️⃣ Staging Layer (stg schema)

Raw dataset imported directly from CSV.

Table:
stg.HR_EmployeeAttrition_Raw

Purpose:
- Preserve original data
- Perform data validation
- Prepare for dimensional modeling


2️⃣ Data Warehouse Layer (dw schema)

Dimension Tables
- dw.dim_employee
- dw.dim_job

Fact Table
dw.fact_employee_snapshot

This structure separates:
- Employee demographics
- Job/organizational attributes
- Compensation & satisfaction metrics
- Attrition outcomes

This design mimics real-world HR analytics warehouses.


3️⃣ Reporting Layer (rpt schema)

Key reporting views:
- rpt.v_executive_summary
- rpt.v_key_driver_department_role
- rpt.v_key_driver_overtime
- rpt.v_key_driver_tenure_band
- rpt.v_risk_segments_current_employees
- rpt.v_top_high_risk_employees

These views simulate executive-ready analytics outputs.


## 📈 Key Insights

🔹 Overall Attrition
- Calculated overall attrition rate using aggregated fact table
- Provided executive-level summary including income & satisfaction averages

🔹 Overtime Impact
- Employees working overtime show significantly higher attrition rates compared to non-overtime employees.
- This indicates workload may be a primary retention driver.

🔹 Tenure Risk Pattern
- Higher attrition observed among:
- Employees with < 2 years at company
- Indicates early-stage retention challenge.

🔹 Department & Role Drivers
Attrition rates vary significantly across departments and job roles, highlighting targeted intervention opportunities.

🔹 Risk Segmentation (Current Employees)

Created explainable, rule-based risk scoring using:
- Overtime status
- Job satisfaction
- Work-life balance
- Environment satisfaction
- Tenure

Employees grouped into:
- High Risk
- Medium Risk
- Low Risk

This enables proactive HR intervention.


## 🧠 Advanced SQL Concepts Used
- Common Table Expressions (CTEs)
- CASE-based banding logic
- Window Functions (DENSE_RANK)
- Conditional Aggregation
- Defensive NULL handling
- Foreign Key constraints
- Multi-layer schema design

## 📸 Screenshots

## Screenshot	                          Description
01_database_setup.png	                Database architecture (schemas & tables)
02_staging_rowcount.png	              Raw import validation
03_dim_fact_rowcounts.png	            Dimensional model validation
04_attrition_overall.png	            Executive KPI summary
05_attrition_by_department.png	      Department-level attrition
06_attrition_by_overtime.png	        Overtime impact
07_tenure_band_analysis.png	          Tenure band analysis
08_risk_segments.png	                Risk segmentation output
09_top_high_risk_employees.png	      High-risk employee ranking


## 🎯 Business Value
This project demonstrates how structured SQL analytics can:
- Identify attrition risk drivers
- Segment workforce risk levels
- Support HR retention strategy
- Enable executive-level reporting

## 📌 Future Enhancements
- Integrate into Power BI dashboard
- Add ML-based attrition prediction
- Implement stored procedures for scheduled reporting
- Create HR KPI dashboard layer

## 👤 Author
Jenil Gohel
SQL | Power BI | Data Analytics
