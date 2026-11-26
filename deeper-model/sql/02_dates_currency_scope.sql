-- Written by Claude (AI) at Thomas Baynum's direction; run and checked against AdventureWorksDW2025.
/* Step 2. Test the assumptions: which months exist, whether amounts are in local currency, rate coverage, whether Corporate double counts, which account types carry units instead of money, intercompany, and finance sales against the sales fact tables.
   Read-only. Run in SSMS against AdventureWorksDW2025. */
USE AdventureWorksDW2025;
SET NOCOUNT ON;
PRINT '== months present (Actual / Budget)';
SELECT s.ScenarioName, YEAR(f.Date) yr, STRING_AGG(m, ',') WITHIN GROUP (ORDER BY m) months
FROM (SELECT DISTINCT ScenarioKey, Date, MONTH(Date) m FROM FactFinance) f JOIN DimScenario s ON s.ScenarioKey=f.ScenarioKey
GROUP BY s.ScenarioName, YEAR(f.Date) ORDER BY 1,2;

PRINT '== Trade Sales (4200) by org, 2013 actual: local currency check';
SELECT o.OrganizationName, c.CurrencyAlternateKey cur, CAST(SUM(f.Amount) AS decimal(18,0)) amt
FROM FactFinance f JOIN DimOrganization o ON o.OrganizationKey=f.OrganizationKey JOIN DimCurrency c ON c.CurrencyKey=o.CurrencyKey
JOIN DimAccount a ON a.AccountKey=f.AccountKey
WHERE a.AccountCodeAlternateKey=4200 AND f.ScenarioKey=1 AND YEAR(f.Date)=2013
GROUP BY o.OrganizationName, c.CurrencyAlternateKey ORDER BY 3 DESC;

PRINT '== FactCurrencyRate coverage for org currencies';
SELECT c.CurrencyAlternateKey, MIN(d.FullDateAlternateKey) first_, MAX(d.FullDateAlternateKey) last_, AVG(r.AverageRate) avg_rate
FROM FactCurrencyRate r JOIN DimCurrency c ON c.CurrencyKey=r.CurrencyKey JOIN DimDate d ON d.DateKey=r.DateKey
WHERE c.CurrencyAlternateKey IN ('CAD','EUR','AUD') GROUP BY c.CurrencyAlternateKey;

PRINT '== Corporate dept rows: which accounts (top 8)';
SELECT TOP 8 a.AccountDescription, a.AccountType, COUNT(*) n
FROM FactFinance f JOIN DimAccount a ON a.AccountKey=f.AccountKey WHERE f.DepartmentGroupKey=1
GROUP BY a.AccountDescription, a.AccountType ORDER BY n DESC;

PRINT '== Do Salaries appear in both Corporate and child depts for same org/date?';
SELECT COUNT(*) overlapping_org_dates FROM (
 SELECT OrganizationKey, Date FROM FactFinance WHERE AccountKey=60 AND DepartmentGroupKey=1 AND ScenarioKey=1
 INTERSECT
 SELECT OrganizationKey, Date FROM FactFinance WHERE AccountKey=60 AND DepartmentGroupKey<>1 AND ScenarioKey=1) x;

PRINT '== Non-currency accounts summed into current model buckets (2013 actual)';
SELECT a.AccountType, a.ValueType, CAST(SUM(f.Amount) AS decimal(18,0)) amt
FROM FactFinance f JOIN DimAccount a ON a.AccountKey=f.AccountKey
WHERE f.ScenarioKey=1 AND YEAR(f.Date)=2013 GROUP BY a.AccountType, a.ValueType ORDER BY 1;

PRINT '== Intercompany (2013 actual)';
SELECT a.AccountDescription, CAST(SUM(f.Amount) AS decimal(18,0)) amt
FROM FactFinance f JOIN DimAccount a ON a.AccountKey=f.AccountKey
WHERE f.ScenarioKey=1 AND YEAR(f.Date)=2013 AND a.AccountDescription LIKE 'Intercompany%' GROUP BY a.AccountDescription;

PRINT '== Sales facts by year vs finance Trade Sales (US orgs, USD)';
WITH fin AS (SELECT YEAR(f.Date) yr, SUM(f.Amount) trade FROM FactFinance f JOIN DimAccount a ON a.AccountKey=f.AccountKey
             WHERE a.AccountCodeAlternateKey=4200 AND f.ScenarioKey=1 GROUP BY YEAR(f.Date)),
 rs AS (SELECT YEAR(OrderDate) yr, SUM(SalesAmount) reseller FROM FactResellerSales GROUP BY YEAR(OrderDate)),
 i AS (SELECT YEAR(OrderDate) yr, SUM(SalesAmount) internet FROM FactInternetSales GROUP BY YEAR(OrderDate)),
 q AS (SELECT CalendarYear yr, SUM(SalesAmountQuota) quota FROM FactSalesQuota GROUP BY CalendarYear)
SELECT COALESCE(fin.yr, rs.yr, i.yr, q.yr) yr, CAST(fin.trade AS decimal(18,0)) finance_trade_sales, CAST(rs.reseller AS decimal(18,0)) reseller,
       CAST(i.internet AS decimal(18,0)) internet, CAST(q.quota AS decimal(18,0)) quota
FROM fin FULL JOIN rs ON rs.yr=fin.yr FULL JOIN i ON i.yr=COALESCE(fin.yr,rs.yr) FULL JOIN q ON q.yr=COALESCE(fin.yr,rs.yr,i.yr) ORDER BY 1;

PRINT '== Sales date ranges';
SELECT 'reseller' src, MIN(OrderDate) a, MAX(OrderDate) b FROM FactResellerSales UNION ALL
SELECT 'internet', MIN(OrderDate), MAX(OrderDate) FROM FactInternetSales;

