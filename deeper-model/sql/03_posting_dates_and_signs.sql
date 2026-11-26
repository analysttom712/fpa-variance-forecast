-- Written by Claude (AI) at Thomas Baynum's direction; run and checked against AdventureWorksDW2025.
/* Step 3. Find out why the months look wrong (drifting posting dates), confirm Corporate is its own department, and list the profit lines with their signs.
   Read-only. Run in SSMS against AdventureWorksDW2025. */
USE AdventureWorksDW2025;
SET NOCOUNT ON;
PRINT '== distinct posting dates 2011-2012 (Actual)';
SELECT STRING_AGG(CONVERT(char(10), d, 120), ' ') WITHIN GROUP (ORDER BY d) FROM (SELECT DISTINCT Date d FROM FactFinance WHERE ScenarioKey=1 AND YEAR(Date) IN (2011,2012)) x;
PRINT '== distinct posting dates Budget';
SELECT STRING_AGG(CONVERT(char(10), d, 120), ' ') WITHIN GROUP (ORDER BY d) FROM (SELECT DISTINCT Date d FROM FactFinance WHERE ScenarioKey=2) x;
PRINT '== DateKey vs Date mismatch';
SELECT COUNT(*) mismatches, MIN(CONVERT(char(10),f.Date,120)) ex_date, MIN(f.DateKey) ex_key FROM FactFinance f WHERE f.DateKey <> CONVERT(int, CONVERT(char(8), f.Date, 112));
PRINT '== Corporate vs children, Salaries 2013 actual, US Southeast';
SELECT d.DepartmentGroupName, CAST(SUM(f.Amount) AS decimal(18,0)) amt FROM FactFinance f JOIN DimDepartmentGroup d ON d.DepartmentGroupKey=f.DepartmentGroupKey
WHERE f.AccountKey=60 AND f.ScenarioKey=1 AND YEAR(f.Date)=2013 AND f.OrganizationKey=6 GROUP BY d.DepartmentGroupName ORDER BY 2 DESC;
PRINT '== Gross margin pieces 2013 actual (by Operator)';
SELECT a.AccountDescription, a.Operator, a.AccountType, CAST(SUM(f.Amount) AS decimal(18,0)) amt FROM FactFinance f JOIN DimAccount a ON a.AccountKey=f.AccountKey
WHERE f.ScenarioKey=1 AND YEAR(f.Date)=2013 AND a.AccountCodeAlternateKey IN (4200,4500,4130,4140,5020,5050,8000,8010,8020,8030,8040,8500) GROUP BY a.AccountDescription, a.Operator, a.AccountType ORDER BY 1;
PRINT '== Budget account coverage: accounts with budget';
SELECT COUNT(DISTINCT AccountKey) budget_accounts FROM FactFinance WHERE ScenarioKey=2;
SELECT COUNT(DISTINCT AccountKey) actual_accounts FROM FactFinance WHERE ScenarioKey=1;

