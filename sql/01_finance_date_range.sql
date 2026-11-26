SELECT YEAR(Date) AS FinanceYear,
       MIN(Date) AS FirstDate,
       MAX(Date) AS LastDate
FROM [AdventureWorksDW2025].[dbo].[FactFinance]
GROUP BY YEAR(Date)