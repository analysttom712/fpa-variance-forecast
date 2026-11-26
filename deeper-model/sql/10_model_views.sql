-- Written by Claude (AI) at Thomas Baynum's direction; run and checked against AdventureWorksDW2025.
/* Model views for the deeper FP&A Power BI model on AdventureWorksDW2025.
   Run in SSMS against AdventureWorksDW2025. Creates schema fpa and five views; changes no data.
   Power BI then imports the five views instead of the single grouped query. */

IF SCHEMA_ID('fpa') IS NULL EXEC('CREATE SCHEMA fpa');
GO

/* Period: posting dates drift (Feb 2011 posts on Mar 1, Apr on May 1, Jun on Jul 1, Jul on Aug 1).
   Moving each date back 3 days puts every posting in its true month, including the
   small year-end entries on Dec 27 and 28. */
CREATE OR ALTER VIEW fpa.DimPeriod AS
SELECT DISTINCT
    EOMONTH(DATEADD(day, -3, Date))           AS PeriodEnd,
    YEAR(DATEADD(day, -3, Date))              AS FiscalYear,
    MONTH(DATEADD(day, -3, Date))             AS FiscalMonth,
    FORMAT(DATEADD(day, -3, Date), 'MMM yyyy') AS PeriodLabel
FROM dbo.FactFinance;
GO

/* Account: keeps the hierarchy, the sign (Operator) and which statement line each account rolls to. */
CREATE OR ALTER VIEW fpa.DimAccount AS
WITH tree AS (
    SELECT AccountKey, ParentAccountKey, AccountCodeAlternateKey, AccountDescription, AccountType, Operator, ValueType,
           CAST(AccountDescription AS nvarchar(400)) AS Path, 0 AS Lvl,
           AccountDescription AS Level0, CAST(NULL AS nvarchar(50)) AS Level1, CAST(NULL AS nvarchar(50)) AS Level2
    FROM dbo.DimAccount WHERE ParentAccountKey IS NULL
    UNION ALL
    SELECT a.AccountKey, a.ParentAccountKey, a.AccountCodeAlternateKey, a.AccountDescription, a.AccountType, a.Operator, a.ValueType,
           CAST(t.Path + ' > ' + a.AccountDescription AS nvarchar(400)), t.Lvl + 1,
           t.Level0, CASE WHEN t.Lvl = 0 THEN a.AccountDescription ELSE t.Level1 END,
           CASE WHEN t.Lvl = 1 THEN a.AccountDescription ELSE t.Level2 END
    FROM dbo.DimAccount a JOIN tree t ON a.ParentAccountKey = t.AccountKey
)
SELECT AccountKey, AccountCodeAlternateKey AS AccountCode, AccountDescription, AccountType, Operator, ValueType,
       Path AS AccountPath, Level0 AS Statement, Level1, Level2,
       CASE
           WHEN AccountCodeAlternateKey IN (4200)            THEN '1 Gross sales'
           WHEN AccountCodeAlternateKey IN (4500)            THEN '2 Intercompany sales (eliminate)'
           WHEN AccountCodeAlternateKey IN (4130, 4140)      THEN '3 Returns and discounts'
           WHEN AccountCodeAlternateKey IN (5020, 5050)      THEN '4 Cost of sales'
           WHEN AccountCodeAlternateKey BETWEEN 6000 AND 6920 THEN '5 Operating expenses'
           WHEN AccountCodeAlternateKey IN (8000, 8010, 8020, 8030, 8040) THEN '6 Other income and expense'
           WHEN AccountCodeAlternateKey IN (8500)            THEN '7 Taxes'
           WHEN Level0 = 'Balance Sheet'                     THEN 'Balance sheet'
           WHEN Level0 = 'Statistical Accounts'              THEN 'Statistical'
           ELSE 'Rollup (no postings)'
       END AS StatementLine,
       /* +1 adds to profit, -1 reduces it. Balance sheet and statistical rows are not summed into profit. */
       CASE
           WHEN AccountCodeAlternateKey IN (4200, 4500, 8000, 8020, 8030, 8040) THEN 1
           WHEN AccountCodeAlternateKey IN (4130, 4140, 5020, 5050, 8010, 8500)
             OR AccountCodeAlternateKey BETWEEN 6000 AND 6920                  THEN -1
           ELSE 0
       END AS ProfitSign
FROM tree;
GO

CREATE OR ALTER VIEW fpa.DimOrganization AS
/* The tree is ragged: US divisions sit one level deeper (under USA Operations) than Canada, France,
   Germany and Australia. OperatingRegion evens it out: North America, European or Pacific Operations. */
SELECT o.OrganizationKey, o.OrganizationName AS Organization, p.OrganizationName AS ParentOrganization,
       CASE WHEN g.ParentOrganizationKey IS NULL THEN p.OrganizationName ELSE g.OrganizationName END AS OperatingRegion,
       o.PercentageOfOwnership AS OwnershipPct, c.CurrencyAlternateKey AS LocalCurrency
FROM dbo.DimOrganization o
LEFT JOIN dbo.DimOrganization p ON p.OrganizationKey = o.ParentOrganizationKey
LEFT JOIN dbo.DimOrganization g ON g.OrganizationKey = p.ParentOrganizationKey
JOIN dbo.DimCurrency c ON c.CurrencyKey = o.CurrencyKey;
GO

/* Corporate is its own department, not a total of the others (checked: its Salaries are not the sum of the rest). */
CREATE OR ALTER VIEW fpa.DimDepartment AS
SELECT DepartmentGroupKey, DepartmentGroupName AS Department FROM dbo.DimDepartmentGroup;
GO

/* Fact: one row per posting, with the true period and the amount in USD at that day's average rate. */
CREATE OR ALTER VIEW fpa.FactFinance AS
SELECT f.FinanceKey, f.ScenarioKey, s.ScenarioName AS Scenario, f.AccountKey, f.OrganizationKey, f.DepartmentGroupKey,
       f.Date AS PostingDate, EOMONTH(DATEADD(day, -3, f.Date)) AS PeriodEnd,
       CAST(f.Amount AS decimal(19, 4)) AS AmountLocal,
       CAST(f.Amount * CASE WHEN c.CurrencyAlternateKey = 'USD' THEN 1 ELSE r.AverageRate END AS decimal(19, 4)) AS AmountUSD,
       CASE WHEN c.CurrencyAlternateKey <> 'USD' AND r.AverageRate IS NULL THEN 1 ELSE 0 END AS MissingRate
FROM dbo.FactFinance f
JOIN dbo.DimScenario s ON s.ScenarioKey = f.ScenarioKey
JOIN dbo.DimOrganization o ON o.OrganizationKey = f.OrganizationKey
JOIN dbo.DimCurrency c ON c.CurrencyKey = o.CurrencyKey
LEFT JOIN dbo.FactCurrencyRate r ON r.CurrencyKey = o.CurrencyKey AND r.DateKey = f.DateKey;
GO
