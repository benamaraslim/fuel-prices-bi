# Fuel Prices BI Dashboard

> **v0.0** — Initial release · No UI design applied yet

A complete **Power BI analytics project** tracking global fuel prices across 150+ countries, built with a full data engineering stack.

---

## Data Analysis & Key Findings

### Vue Globale — Prix des Carburants
![Vue Globale](screenshots/dashboard_overview.png)

**Global overview across 60 countries:**

| KPI | Value |
|-----|-------|
| Average gasoline price | **$1.095 / L** |
| Cheapest country | **$0.020 / L** (Libya / Venezuela — heavily subsidized) |
| Most expensive country | **$2.100 / L** (Netherlands) |
| Price spread (max − min) | **$2.080** — enormous global disparity |

**Top 8 most expensive:** Netherlands, Norway, Israel, France, Italy, Singapore, Germany, Switzerland — all high-income countries with heavy fuel taxation.

**Regional averages:** Europe leads (~$1.70/L), followed by Oceania (~$1.30/L). Middle East and Southeast Asia are the cheapest regions due to subsidies and local oil production.

> The **105x price ratio** between the cheapest and most expensive country reflects the massive impact of government subsidies and taxation — not just production costs.

---

### Tendances — Évolution des Prix (2015–2026)
![Tendances](screenshots/dashboard_tendances.png)

**Price trend indicators:**

| KPI | Value |
|-----|-------|
| Average monthly gasoline | **$0.762 / L** |
| Month-over-Month change | **+1.1%** |
| Year-over-Year change | **+8.4%** |
| Brent crude (latest) | **$92.40 / bbl** |
| WTI crude (latest) | **$73.60 / bbl** |

**Key observations from the 2015–2026 curve:**

- **2015–2016:** Sharp drop from ~$0.85/L to ~$0.45/L — OPEC supply glut, Brent fell below $30/bbl
- **2020:** Historic low (~$0.40/L) — COVID-19 demand collapse; Brent briefly went negative (April 2020)
- **2021–2022:** Rapid surge to ~$1.20/L peak — post-COVID recovery + Russia-Ukraine war pushed Brent above $120/bbl
- **2023–2024:** Gradual normalization around $0.80–0.90/L
- **2026:** Rising again (+8.4% YoY) — renewed supply constraints and geopolitical pressure

> The **Brent/WTI spread of $18.80** ($92.40 − $73.60) is unusually wide, signaling logistical bottlenecks or quality differentials in the current market.

---

### Analyse Asie — Accessibilité & Transition Énergétique
![Analyse Asie](screenshots/dashboard_asie.png)

**Asia-specific metrics:**

| KPI | Value |
|-----|-------|
| Avg Affordability Index | **33.4** |
| Avg EV Adoption | **1.96%** |
| Total CO2 (Transport) | **2,087 MT** |
| Total Subsidy Cost | **$35.9 Billion USD** |
| Countries with subsidies | **12 / ~20 Asian countries** |

**Affordability Index highlights (higher = more affordable relative to income):**
- **Brunei: 236.8** — extreme outlier; government sells fuel at ~$0.31/L to citizens
- **Singapore: ~90, Japan: ~80** — high incomes offset moderate prices
- **China: 25.8, India: 8.0** — despite lower pump prices, fuel represents a large income share
- **Thailand: ~5** — low wages make fuel relatively expensive for locals

**EV adoption leaders:**
- **South Korea (~10%), China (~9.4%)** — major EV manufacturers with strong incentive policies
- **Singapore (~6%), Taiwan (~5%)** — city-states with targeted green transport mandates
- **India (2.1%), Malaysia (2.5%)** — still in early adoption phase

> Asia's **$35.9 Billion in annual fuel subsidies** keeps prices artificially low across 12 countries, but simultaneously suppresses EV transition incentives and contributes to **2,087 MT of transport CO2**.

---

### Fiscalité — Charge Fiscale Mondiale
![Fiscalité](screenshots/dashboard_fiscalite.png)

**Tax burden indicators:**

| KPI | Value |
|-----|-------|
| Avg gasoline tax rate | **32.7%** |
| Avg total tax per liter | **$0.493 / L** |
| Countries with carbon tax | **11** |
| Highest tax per liter | **$1.280 / L** (Netherlands) |

**Top tax countries (total tax per liter):** Netherlands ($1.28), Norway (~$1.10), France ($1.10), Italy (~$1.05), Germany ($1.00), United Kingdom (~$0.98), Sweden (~$0.95), South Korea (~$0.65)

**Tax burden categories:**
- **Very High** (3 countries, 27%) — taxes represent 60%+ of pump price (Netherlands, Norway, France)
- **High** (4 countries, 36%) — Germany, UK, Sweden, South Korea
- **Moderate** (4 countries, 36%) — Canada, Australia, Brazil, China

**Carbon tax adoption (11 countries):** Canada, France, Germany, Sweden lead. Indonesia, Iran, Saudi Arabia apply 0% fuel tax — purely subsidy-driven pricing.

> **France (58%) and Germany (55%)** — over half of what consumers pay at the pump is government revenue, funding infrastructure and climate transition.

> The contrast between **Netherlands ($1.28/L tax)** and **Iran ($0.00/L tax)** illustrates two opposite energy policy philosophies: fiscal internalization of externalities vs. state-subsidized energy as a social contract.

---

## Architecture

```
CSV Files (6 sources)
       │
       ▼
 etl_pipeline.py          ← Python ETL (Extract → Transform → Load)
       │
       ▼
SQL Server — FuelPricesBI
 ├── staging.*            ← Raw CSV data
 ├── dw.*                 ← Star schema (Dimensions + Facts)
 │    ├── DimCountry
 │    ├── DimDate
 │    ├── DimSubsidyPolicy
 │    ├── FactFuelPrices
 │    ├── FactCrudeOil
 │    ├── FactTaxPolicy
 │    └── FactMonthlyTrend
 └── rpt.*                ← Reporting views (used by Power BI)
       │
       ▼
Power BI Semantic Model (model.bim)
  ├── 6 tables + relationships
  ├── Parameter: DataPath (CSV folder)
  └── 30+ DAX measures
       │
       ▼
Power BI Report (4 pages)
  ├── Vue Globale    — World KPIs, map, country rankings
  ├── Tendances      — Monthly trends, Brent correlation
  ├── Asie           — Asia deep dive (affordability, EV, CO2)
  └── Fiscalite      — Tax burden comparison, carbon tax
```

---

## Data Sources

| File | Description |
|------|-------------|
| `global_fuel_prices.csv` | Gasoline & diesel prices (USD/L) — all countries |
| `asia_fuel_prices_detailed.csv` | Asia: LPG, affordability index, EV adoption, CO2 |
| `asia_subsidy_tracker.csv` | Fuel subsidy tracking — type, cost, % GDP |
| `crude_oil_annual.csv` | Brent & WTI annual prices (2015–2026) |
| `fuel_tax_comparison.csv` | Tax breakdown per country — excise, VAT, carbon tax |
| `price_trend_monthly.csv` | Monthly price trends — MoM & YoY changes |

---

## Project Structure

```
fuel-prices-bi/
├── etl_pipeline.py                        # Python ETL pipeline
├── sql_server_schema.sql                  # SQL Server schema + stored procedures + views
├── dax_measures.md                        # 30+ DAX measures documentation
├── fuel_prices_dashboard.html             # Standalone HTML dashboard (Chart.js)
├── fuel_prices_report.pbip                # Power BI project file
├── fuel_prices_report.Dataset/
│   ├── model.bim                          # Semantic model (tables, relations, params)
│   └── definition.pbism
└── fuel_prices_report.Report/
    ├── report.json                        # Report definition (visuals, pages, config)
    └── definition.pbir
```

---

## Key DAX Measures

| Category | Measures |
|----------|----------|
| **Global KPIs** | `Avg Gasoline Global`, `Median Gasoline Global`, `Countries Count`, `Max/Min Gasoline Price`, `Price Range` |
| **Rankings** | `Country Gasoline World Rank`, `Most Expensive Country`, `Cheapest Country` |
| **Subsidies** | `Total Subsidy Cost Bn USD`, `Subsidized Countries Count`, `Avg Subsidy Pct GDP` |
| **Tax** | `Avg Gasoline Tax Pct`, `Countries With Carbon Tax`, `Avg Tax Share Of Price Pct` |
| **Crude Oil** | `Brent Latest Year`, `WTI Latest Year`, `Brent YoY Change Selected Year`, `Brent Peak Year` |
| **Trends** | `Avg MoM Change Pct`, `Avg YoY Change Pct`, `Gasoline 3M Moving Avg` |
| **Asia** | `Avg Affordability Index Asia`, `Avg EV Adoption Pct Asia`, `Total CO2 Transport MT` |

---

## ETL Pipeline

The Python ETL (`etl_pipeline.py`) implements a full **Extract → Transform → Load** cycle:

1. **Extract** — reads 6 CSV files with `pandas`
2. **Transform** — per-table cleaning (types, booleans, deduplication, null handling)
3. **Quality checks** — validates nulls, negative prices, data completeness
4. **Load** — writes to SQL Server `staging.*` via SQLAlchemy (`chunked, multi-row inserts`)
5. **DW procedures** — calls 4 stored procedures to populate the star schema
6. **Analytics** — generates regional averages, Top 5 rankings, Brent correlation (r=0.87), exports `analysis_summary.csv`

---

## SQL Server Schema

Three schemas with clear separation of concerns:

| Schema | Purpose |
|--------|---------|
| `staging` | Raw CSV data loaded by Python |
| `dw` | Star schema — dimensions + fact tables |
| `rpt` | Views consumed directly by Power BI |

**Stored Procedures:**
- `dw.usp_LoadDimCountry` — MERGE upsert for country dimension
- `dw.usp_LoadFactFuelPrices` — full reload of price facts
- `dw.usp_LoadFactCrudeOil` — Brent/WTI annual data
- `dw.usp_LoadFactMonthlyTrend` — monthly trend data
- `dw.usp_RunFullETL` — orchestrates all 4 procedures

---

## Setup

### Prerequisites
- Python 3.9+
- SQL Server (local or remote) with ODBC Driver 17
- Power BI Desktop (for `.pbip` format)

### 1 — Install Python dependencies
```bash
pip install pandas sqlalchemy pyodbc
```

### 2 — Place CSV files
Copy the 6 CSV files to:
```
C:\Users\<you>\Downloads\Compressed\archive_3\
```
Or update `DATA_DIR` in `etl_pipeline.py`.

### 3 — Create the database
```sql
-- Run in SSMS or sqlcmd:
sqlcmd -S localhost -i sql_server_schema.sql
```

### 4 — Run the ETL
```bash
python etl_pipeline.py
```

### 5 — Open in Power BI
Open `fuel_prices_report.pbip` in Power BI Desktop.
Update the `DataPath` parameter if needed (Model → Parameters).

### 6 — HTML Dashboard (no dependencies)
Open `fuel_prices_dashboard.html` directly in a browser.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Data ingestion | Python, pandas, SQLAlchemy |
| Database | SQL Server 2019+, T-SQL |
| BI Semantic Model | Power BI PBIP format, DAX |
| Visualization | Power BI Desktop, Chart.js (HTML) |
| Version control | Git, GitHub |

---

## Roadmap

- [x] v0.0 — ETL pipeline, SQL schema, semantic model, 4-page report
- [ ] v0.1 — UI design: per-page color themes, styled KPI cards, chart borders
- [ ] v0.2 — Add README screenshots from Power BI
- [ ] v1.0 — Full production release

---

## License

MIT
