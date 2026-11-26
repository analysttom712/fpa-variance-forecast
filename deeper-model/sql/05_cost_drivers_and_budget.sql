-- Written by Claude (AI) at Thomas Baynum's direction; run and checked against AdventureWorksDW2025.
/* Step 5. What drives the margin decline: operating expenses by line and department, headcount, and 2011 budget against actual on a like-for-like basis.
   Read-only. Run in SSMS against AdventureWorksDW2025. */
USE AdventureWorksDW2025;
SET NOCOUNT ON;
PRINT '== small year-end dates: accounts';
SELECT CONVERT(char(10), f.Date, 120) d, a.AccountDescription, COUNT(*) n FROM FactFinance f JOIN DimAccount a ON a.AccountKey=f.AccountKey
WHERE f.Date IN ('2011-12-28','2012-12-27','2013-12-28') GROUP BY f.Date, a.AccountDescription ORDER BY 1;

PRINT '== OpEx lines, USD, 2011 vs 2013 and growth (Actual)';
WITH x AS (
  SELECT YEAR(f.Date) yr, p.AccountDescription grp,
         f.Amount * CASE WHEN c.CurrencyAlternateKey='USD' THEN 1 ELSE r.AverageRate END amt
  FROM FactFinance f JOIN DimAccount a ON a.AccountKey=f.AccountKey JOIN DimAccount p ON p.AccountKey = CASE WHEN a.ParentAccountKey=58 THEN a.AccountKey ELSE a.ParentAccountKey END
  JOIN DimOrganization o ON o.OrganizationKey=f.OrganizationKey JOIN DimCurrency c ON c.CurrencyKey=o.CurrencyKey
  LEFT JOIN FactCurrencyRate r ON r.CurrencyKey=o.CurrencyKey AND r.DateKey=f.DateKey
  WHERE f.ScenarioKey=1 AND a.AccountCodeAlternateKey BETWEEN 6000 AND 6920)
SELECT grp, CAST(SUM(CASE WHEN yr=2011 THEN amt END) AS decimal(18,0)) y2011, CAST(SUM(CASE WHEN yr=2012 THEN amt END) AS decimal(18,0)) y2012,
       CAST(SUM(CASE WHEN yr=2013 THEN amt END) AS decimal(18,0)) y2013,
       CAST(100*(SUM(CASE WHEN yr=2013 THEN amt END)/SUM(CASE WHEN yr=2011 THEN amt END)-1) AS decimal(7,1)) growth_pct
FROM x GROUP BY grp ORDER BY y2013 DESC;

PRINT '== Net sales growth 2011->2013 for comparison: 21065121 -> 35670823';
PRINT '== OpEx by department, USD 2013 and growth vs 2011';
WITH x AS (
  SELECT YEAR(f.Date) yr, d.DepartmentGroupName dept,
         f.Amount * CASE WHEN c.CurrencyAlternateKey='USD' THEN 1 ELSE r.AverageRate END amt
  FROM FactFinance f JOIN DimAccount a ON a.AccountKey=f.AccountKey JOIN DimDepartmentGroup d ON d.DepartmentGroupKey=f.DepartmentGroupKey
  JOIN DimOrganization o ON o.OrganizationKey=f.OrganizationKey JOIN DimCurrency c ON c.CurrencyKey=o.CurrencyKey
  LEFT JOIN FactCurrencyRate r ON r.CurrencyKey=o.CurrencyKey AND r.DateKey=f.DateKey
  WHERE f.ScenarioKey=1 AND a.AccountCodeAlternateKey BETWEEN 6000 AND 6920)
SELECT dept, CAST(SUM(CASE WHEN yr=2011 THEN amt END) AS decimal(18,0)) y2011, CAST(SUM(CASE WHEN yr=2013 THEN amt END) AS decimal(18,0)) y2013,
       CAST(100*(SUM(CASE WHEN yr=2013 THEN amt END)/SUM(CASE WHEN yr=2011 THEN amt END)-1) AS decimal(7,1)) growth_pct
FROM x GROUP BY dept ORDER BY y2013 DESC;

PRINT '== Headcount (9510) latest posting per year, all orgs';
SELECT YEAR(f.Date) yr, CAST(SUM(f.Amount) AS decimal(18,0)) headcount FROM FactFinance f
WHERE f.AccountKey=96 AND f.ScenarioKey=1 AND f.Date IN (SELECT MAX(Date) FROM FactFinance WHERE AccountKey=96 AND ScenarioKey=1 GROUP BY YEAR(Date))
GROUP BY YEAR(f.Date) ORDER BY 1;

PRINT '== Budget vs actual 2011 on budgeted posting dates and budgeted accounts, USD';
WITH x AS (
  SELECT f.ScenarioKey sk, f.AccountKey, f.Date,
         f.Amount * CASE WHEN c.CurrencyAlternateKey='USD' THEN 1 ELSE r.AverageRate END amt
  FROM FactFinance f JOIN DimOrganization o ON o.OrganizationKey=f.OrganizationKey JOIN DimCurrency c ON c.CurrencyKey=o.CurrencyKey
  LEFT JOIN FactCurrencyRate r ON r.CurrencyKey=o.CurrencyKey AND r.DateKey=f.DateKey
  WHERE YEAR(f.Date)=2011),
b AS (SELECT DISTINCT AccountKey, Date FROM x WHERE sk=2)
SELECT a.AccountType, CAST(SUM(CASE WHEN x.sk=1 THEN amt END) AS decimal(18,0)) actual, CAST(SUM(CASE WHEN x.sk=2 THEN amt END) AS decimal(18,0)) budget,
  CAST(100*(SUM(CASE WHEN x.sk=1 THEN amt END)/NULLIF(SUM(CASE WHEN x.sk=2 THEN amt END),0)-1) AS decimal(7,1)) var_pct
FROM x JOIN b ON b.AccountKey=x.AccountKey AND b.Date=x.Date JOIN DimAccount a ON a.AccountKey=x.AccountKey
GROUP BY a.AccountType ORDER BY 1;

