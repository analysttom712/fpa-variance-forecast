# FP&A variance and forecast (AdventureWorks)

A budget-versus-actual dashboard and a backtested forecast, built in SQL Server and Power BI on Microsoft's AdventureWorksDW sample data. It also covers the errors I found in my own work. Case study: [analysttom712.github.io/projects/fpa-variance.html](https://analysttom712.github.io/projects/fpa-variance.html).

## The five business questions

1. **Variance:** How does actual spending compare to budget by account, and which accounts vary most?
2. **Trend:** How have revenue and expenditures moved year over year, and is the gap widening?
3. **Mix:** Which account types take the largest share, and has the mix shifted?
4. **Consistency and health:** Which results hold year after year, and what do the balance sheet ratios say?
5. **Forecastability:** Which accounts follow a predictable pattern, and which are too volatile to forecast?

## Data

The data is AdventureWorksDW, Microsoft's free sample for a fictional bike manufacturer, restored in SQL Server. It has actuals by account for 2010 to 2013, but budgets only for 2010 and 2011. The database backup is not in this repo. Download it from [Microsoft](https://learn.microsoft.com/en-us/sql/samples/adventureworks-install-configure) and restore it in SQL Server Management Studio.

## What's here

| Path | What it is |
|---|---|
| `BI_Project_FPA_2026.pbix` | The Power BI report and model |
| `dax/fpa-measures.dax` | All 35 DAX measures, exported from the model. Paste into DAX query view and run. |
| `sql/` | Queries I used to check the shape of `FactFinance` and `DimAccount` before building |
| `images/` | Report screenshots |

## What I caught

- **Wrong period count.** The first result showed accounts 265% to 658% over budget. Four years of actuals were being compared with two years of budget. The fix is a measure that counts actuals only in budgeted years. `Original Variance` and `Variance` stay side by side on purpose so the difference is visible.
- **A blank read as zero.** It produced a false $5.46M swing until an `ISBLANK` check fixed it.
- **Four data-shape problems:**
  - a year with only one month of data
  - a missing December
  - balance sheet accounts that are snapshots, not activity
  - rollup accounts that are all zero

  On a like-for-like January to November basis, net operating margin fell from 21.2% to 19.2%.

## Results

The forecast predicts 2013 as 2012 plus the prior year's change. In the backtest it came within 3.1% in total but missed many individual accounts. That is one test point per account, and a lesson that a total can hide detail.

![Revenue, expenditures and net operating margin, 2011 to 2013](images/fpa-margin-trend.png)

![Budget versus actual by expense account](images/fpa-variance-table.png)

![Liquidity and profitability ratios by year](images/fpa-ratios.webp)

## How to open

1. Restore AdventureWorksDW in SQL Server.
2. Open `BI_Project_FPA_2026.pbix` in Power BI Desktop.
3. If the server name differs from mine, go to Transform data > Data source settings, point it at your SQL Server, then refresh.

## Write-ups

- [From Benefits to Business Questions: I Built an FP&A Variance Dashboard from Scratch](https://www.linkedin.com/pulse/budget-vs-actual-what-i-learned-building-fpa-dashboard-thomas-baynum-ldywe)
- [The Gap Between Revenue and Expenses. What the Data Said](https://www.linkedin.com/pulse/gap-between-revenue-expenses-what-data-said-thomas-baynum-cp2be)
- [I Almost Posted the Wrong Numbers: What a Power BI Project Taught Me About Trusting Data](https://www.linkedin.com/pulse/i-almost-posted-wrong-numbers-what-power-bi-project-taught-baynum-ewhke)

## Credits

I chose the questions, checked the shape of the data, and tested and corrected every result. The SQL and DAX were written with AI assistance. I read and tested every query and measure myself.

Tools: SQL Server (SSMS), Power BI, DAX.
