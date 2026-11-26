-- Written by Claude (AI) at Thomas Baynum's direction; run and checked against AdventureWorksDW2025.
/* Step 4. Rebuild the P&L in USD, net of returns and discounts, without intercompany, and compare it with what the original model reports. Then rank organizations by 2013 operating profit.
   Read-only. Run in SSMS against AdventureWorksDW2025. */
USE AdventureWorksDW2025;
SET NOCOUNT ON;
PRINT '== rows per posting date around year ends';
SELECT CONVERT(char(10), Date, 120) d, ScenarioKey, COUNT(*) n, COUNT(DISTINCT AccountKey) accts
FROM FactFinance WHERE Date IN ('2011-12-28','2011-12-29','2012-12-27','2012-12-28','2010-12-29','2013-12-28') GROUP BY Date, ScenarioKey ORDER BY 1,2;

PRINT '== rate coverage on posting dates (non-USD rows without a same-day rate)';
SELECT COUNT(*) rows_without_rate FROM FactFinance f JOIN DimOrganization o ON o.OrganizationKey=f.OrganizationKey
LEFT JOIN FactCurrencyRate r ON r.CurrencyKey=o.CurrencyKey AND r.DateKey=f.DateKey
WHERE o.CurrencyKey <> (SELECT CurrencyKey FROM DimCurrency WHERE CurrencyAlternateKey='USD') AND r.CurrencyKey IS NULL;

PRINT '== P&L by year, local sum vs USD converted (Actual)';
WITH x AS (
  SELECT YEAR(f.Date) yr, a.AccountCodeAlternateKey code, f.Amount amt_local,
         f.Amount * CASE WHEN c.CurrencyAlternateKey='USD' THEN 1 ELSE r.AverageRate END amt_usd
  FROM FactFinance f JOIN DimAccount a ON a.AccountKey=f.AccountKey
  JOIN DimOrganization o ON o.OrganizationKey=f.OrganizationKey JOIN DimCurrency c ON c.CurrencyKey=o.CurrencyKey
  LEFT JOIN FactCurrencyRate r ON r.CurrencyKey=o.CurrencyKey AND r.DateKey=f.DateKey
  WHERE f.ScenarioKey=1),
p AS (
  SELECT yr,
    SUM(CASE WHEN code IN (4200,4500) THEN amt_usd END) gross_sales,
    SUM(CASE WHEN code = 4500 THEN amt_usd END) intercompany,
    SUM(CASE WHEN code IN (4130,4140) THEN amt_usd END) returns_disc,
    SUM(CASE WHEN code IN (5020,5050) THEN amt_usd END) cogs,
    SUM(CASE WHEN code BETWEEN 6000 AND 6920 THEN amt_usd END) opex,
    SUM(CASE WHEN code IN (8000,8020,8030,8040) THEN amt_usd END) - SUM(CASE WHEN code=8010 THEN amt_usd END) other_net,
    SUM(CASE WHEN code = 8500 THEN amt_usd END) taxes,
    SUM(CASE WHEN code IN (4200,4500,8000,8020,8030,8040) THEN amt_local END) model_revenue_local,
    SUM(CASE WHEN code IN (4130,4140,5020,5050,8010,8500) OR code BETWEEN 6000 AND 6920 THEN amt_local END) model_exp_local
  FROM x GROUP BY yr)
SELECT yr,
  CAST(model_revenue_local AS decimal(18,0)) model_rev_local, CAST(model_exp_local AS decimal(18,0)) model_exp_local,
  CAST(100*(model_revenue_local-model_exp_local)/model_revenue_local AS decimal(5,2)) model_margin_pct,
  CAST(gross_sales-intercompany-returns_disc AS decimal(18,0)) net_sales_usd_ex_ic,
  CAST(gross_sales-intercompany-returns_disc-cogs AS decimal(18,0)) gross_margin_usd,
  CAST(100*(gross_sales-intercompany-returns_disc-cogs)/(gross_sales-intercompany-returns_disc) AS decimal(5,2)) gm_pct,
  CAST(gross_sales-intercompany-returns_disc-cogs-opex AS decimal(18,0)) operating_profit_usd,
  CAST(100*(gross_sales-intercompany-returns_disc-cogs-opex)/(gross_sales-intercompany-returns_disc) AS decimal(5,2)) op_pct,
  CAST(gross_sales-intercompany-returns_disc-cogs-opex+other_net-taxes AS decimal(18,0)) net_income_usd,
  CAST(100*(gross_sales-intercompany-returns_disc-cogs-opex+other_net-taxes)/(gross_sales-intercompany-returns_disc) AS decimal(5,2)) ni_pct
FROM p ORDER BY yr;

PRINT '== Same, Jan-Nov posting dates only (like-for-like with the original write-up)';
WITH x AS (
  SELECT YEAR(f.Date) yr, a.AccountCodeAlternateKey code, f.Amount amt_local
  FROM FactFinance f JOIN DimAccount a ON a.AccountKey=f.AccountKey WHERE f.ScenarioKey=1 AND MONTH(f.Date) <= 11)
SELECT yr, CAST(100*(SUM(CASE WHEN code IN (4200,4500,8000,8020,8030,8040) THEN amt_local END)
     - SUM(CASE WHEN code IN (4130,4140,5020,5050,8010,8500) OR code BETWEEN 6000 AND 6920 THEN amt_local END))
     / SUM(CASE WHEN code IN (4200,4500,8000,8020,8030,8040) THEN amt_local END) AS decimal(5,2)) model_margin_pct_check
FROM x GROUP BY yr ORDER BY yr;

PRINT '== Org contribution to 2013 operating profit (USD, ex intercompany)';
WITH x AS (
  SELECT o.OrganizationName org, a.AccountCodeAlternateKey code,
         f.Amount * CASE WHEN c.CurrencyAlternateKey='USD' THEN 1 ELSE r.AverageRate END amt
  FROM FactFinance f JOIN DimAccount a ON a.AccountKey=f.AccountKey
  JOIN DimOrganization o ON o.OrganizationKey=f.OrganizationKey JOIN DimCurrency c ON c.CurrencyKey=o.CurrencyKey
  LEFT JOIN FactCurrencyRate r ON r.CurrencyKey=o.CurrencyKey AND r.DateKey=f.DateKey
  WHERE f.ScenarioKey=1 AND YEAR(f.Date)=2013)
SELECT org,
  CAST(SUM(CASE WHEN code=4200 THEN amt END) - SUM(CASE WHEN code IN (4130,4140) THEN amt ELSE 0 END) AS decimal(18,0)) net_sales,
  CAST(SUM(CASE WHEN code=4200 THEN amt END) - SUM(CASE WHEN code IN (4130,4140,5020,5050) OR code BETWEEN 6000 AND 6920 THEN amt ELSE 0 END) AS decimal(18,0)) op_profit,
  CAST(100*(SUM(CASE WHEN code=4200 THEN amt END) - SUM(CASE WHEN code IN (4130,4140,5020,5050) OR code BETWEEN 6000 AND 6920 THEN amt ELSE 0 END))
     / NULLIF(SUM(CASE WHEN code=4200 THEN amt END) - SUM(CASE WHEN code IN (4130,4140) THEN amt ELSE 0 END),0) AS decimal(6,2)) op_pct
FROM x GROUP BY org ORDER BY op_profit DESC;

