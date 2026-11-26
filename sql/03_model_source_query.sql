-- Written by Thomas Baynum.
-- Source query behind the Power BI 'Query' table (copied from the model's Power Query step).
-- Grain: account x scenario x year x month. Amounts are in local currency (not converted to USD);
-- see deeper-model/sql/10_model_views.sql for the USD-converted version.

SELECT DimAccount.AccountType,
       CASE 
           WHEN DimAccount.AccountType = 'Expenditures' THEN 'Cost'
           ELSE 'Revenue or Balance Sheet'
       END AS AccountBucket,
       DimAccount.AccountCodeAlternateKey AS AccountCode,
       DimAccount.AccountDescription,
       DimScenario.ScenarioName,
       YEAR(FactFinance.Date) AS FinanceYear,
       MONTH(FactFinance.Date) AS MonthNum,
       SUM(FactFinance.Amount) AS TotalAmount
FROM FactFinance
JOIN DimScenario ON FactFinance.ScenarioKey = DimScenario.ScenarioKey
JOIN DimAccount ON FactFinance.AccountKey = DimAccount.AccountKey
GROUP BY DimAccount.AccountType,
         CASE 
             WHEN DimAccount.AccountType = 'Expenditures' THEN 'Cost'
             ELSE 'Revenue or Balance Sheet'
         END,
         DimAccount.AccountCodeAlternateKey,
         DimAccount.AccountDescription,
         DimScenario.ScenarioName,
         YEAR(FactFinance.Date),
         MONTH(FactFinance.Date);

