/* Step 1. What is in the database: every table and row count, the FactFinance columns, scenarios by year, organizations, departments and the full account tree with postings per account.
   Read-only. Run in SSMS against AdventureWorksDW2025. */
USE AdventureWorksDW2025;
SET NOCOUNT ON;
PRINT '== tables and rows';
SELECT t.name, SUM(p.rows) AS rows_
FROM sys.tables t JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
GROUP BY t.name ORDER BY rows_ DESC;

PRINT '== FactFinance columns';
SELECT c.name, ty.name AS type_ FROM sys.columns c JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.FactFinance');

PRINT '== FactFinance by scenario and year';
SELECT s.ScenarioName, YEAR(f.Date) AS yr, COUNT(*) AS rows_, COUNT(DISTINCT MONTH(f.Date)) AS months,
       MIN(f.Date) AS first_, MAX(f.Date) AS last_, CAST(SUM(f.Amount) AS decimal(18,2)) AS amount
FROM FactFinance f JOIN DimScenario s ON s.ScenarioKey = f.ScenarioKey
GROUP BY s.ScenarioName, YEAR(f.Date) ORDER BY 1, 2;

PRINT '== organizations used in FactFinance';
SELECT o.OrganizationKey, o.OrganizationName, o.ParentOrganizationKey, o.PercentageOfOwnership, c.CurrencyName, COUNT(*) AS rows_
FROM FactFinance f JOIN DimOrganization o ON o.OrganizationKey = f.OrganizationKey
LEFT JOIN DimCurrency c ON c.CurrencyKey = o.CurrencyKey
GROUP BY o.OrganizationKey, o.OrganizationName, o.ParentOrganizationKey, o.PercentageOfOwnership, c.CurrencyName ORDER BY 1;

PRINT '== all organizations';
SELECT OrganizationKey, ParentOrganizationKey, OrganizationName FROM DimOrganization ORDER BY 1;

PRINT '== department groups used';
SELECT d.DepartmentGroupKey, d.DepartmentGroupName, d.ParentDepartmentGroupKey, COUNT(*) AS rows_
FROM FactFinance f JOIN DimDepartmentGroup d ON d.DepartmentGroupKey = f.DepartmentGroupKey
GROUP BY d.DepartmentGroupKey, d.DepartmentGroupName, d.ParentDepartmentGroupKey ORDER BY 1;

PRINT '== account hierarchy';
SELECT AccountKey, ParentAccountKey, AccountCodeAlternateKey, AccountDescription, AccountType, Operator, ValueType,
       (SELECT COUNT(*) FROM FactFinance f WHERE f.AccountKey = a.AccountKey) AS fact_rows
FROM DimAccount a ORDER BY AccountKey;

