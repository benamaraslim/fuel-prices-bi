-- ============================================================
-- RAPPORT BI - PRIX DES CARBURANTS MONDIAUX
-- SQL Server Schema + Stored Procedures + Views
-- Base : FuelPricesBI
-- ============================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'FuelPricesBI')
    CREATE DATABASE FuelPricesBI;
GO

USE FuelPricesBI;
GO

-- ============================================================
-- SCHEMA STAGING (chargement brut des CSV)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    EXEC('CREATE SCHEMA staging');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dw')
    EXEC('CREATE SCHEMA dw');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'rpt')
    EXEC('CREATE SCHEMA rpt');
GO

-- --------------------------------------------------------
-- STAGING TABLES
-- --------------------------------------------------------
DROP TABLE IF EXISTS staging.GlobalFuelPrices;
CREATE TABLE staging.GlobalFuelPrices (
    country                 NVARCHAR(100),
    region                  NVARCHAR(100),
    iso3                    CHAR(3),
    gasoline_usd_per_liter  DECIMAL(6,3),
    diesel_usd_per_liter    DECIMAL(6,3),
    local_currency          NVARCHAR(10),
    gasoline_local_price    DECIMAL(12,4),
    diesel_local_price      DECIMAL(12,4),
    price_date              DATE,
    is_asian                BIT,
    avg_fuel_usd            DECIMAL(6,3),
    load_timestamp          DATETIME2 DEFAULT SYSUTCDATETIME()
);

DROP TABLE IF EXISTS staging.AsiaFuelDetailed;
CREATE TABLE staging.AsiaFuelDetailed (
    country                     NVARCHAR(100),
    sub_region                  NVARCHAR(100),
    iso3                        CHAR(3),
    gasoline_usd_per_liter      DECIMAL(6,3),
    diesel_usd_per_liter        DECIMAL(6,3),
    lpg_usd_per_kg              DECIMAL(6,3),
    avg_monthly_income_usd      DECIMAL(10,2),
    fuel_affordability_index    DECIMAL(8,2),
    oil_import_dependency_pct   DECIMAL(5,1),
    refinery_capacity_kbpd      INT,
    ev_adoption_pct             DECIMAL(5,2),
    fuel_subsidy_active         BIT,
    subsidy_cost_bn_usd         DECIMAL(8,2),
    co2_transport_mt            DECIMAL(10,2),
    price_date                  DATE,
    gasoline_pct_daily_wage     DECIMAL(6,2),
    load_timestamp              DATETIME2 DEFAULT SYSUTCDATETIME()
);

DROP TABLE IF EXISTS staging.AsiaSubsidyTracker;
CREATE TABLE staging.AsiaSubsidyTracker (
    country                     NVARCHAR(100),
    iso3                        CHAR(3),
    gasoline_subsidized         BIT,
    diesel_subsidized           BIT,
    subsidy_type                NVARCHAR(50),
    annual_subsidy_cost_bn_usd  DECIMAL(8,2),
    subsidy_pct_gdp             DECIMAL(5,2),
    subsidy_description         NVARCHAR(500),
    last_price_change           DATE,
    pricing_mechanism           NVARCHAR(200),
    regulator                   NVARCHAR(50),
    load_timestamp              DATETIME2 DEFAULT SYSUTCDATETIME()
);

DROP TABLE IF EXISTS staging.CrudeOilAnnual;
CREATE TABLE staging.CrudeOilAnnual (
    year                    SMALLINT,
    brent_avg_usd_bbl       DECIMAL(8,2),
    wti_avg_usd_bbl         DECIMAL(8,2),
    brent_yoy_change_pct    DECIMAL(7,2),
    wti_yoy_change_pct      DECIMAL(7,2),
    key_event               NVARCHAR(200),
    brent_wti_spread        DECIMAL(7,2),
    avg_price_usd_bbl       DECIMAL(8,2),
    load_timestamp          DATETIME2 DEFAULT SYSUTCDATETIME()
);

DROP TABLE IF EXISTS staging.FuelTaxComparison;
CREATE TABLE staging.FuelTaxComparison (
    country                 NVARCHAR(100),
    region                  NVARCHAR(100),
    gasoline_tax_pct        DECIMAL(5,1),
    diesel_tax_pct          DECIMAL(5,1),
    vat_pct                 DECIMAL(5,1),
    excise_usd_per_liter    DECIMAL(6,3),
    carbon_tax_active       BIT,
    total_tax_usd_per_liter DECIMAL(6,3),
    tax_burden_category     NVARCHAR(20),
    load_timestamp          DATETIME2 DEFAULT SYSUTCDATETIME()
);

DROP TABLE IF EXISTS staging.PriceTrendMonthly;
CREATE TABLE staging.PriceTrendMonthly (
    date                    DATE,
    year                    SMALLINT,
    month                   TINYINT,
    country                 NVARCHAR(100),
    region                  NVARCHAR(100),
    gasoline_usd_per_liter  DECIMAL(6,3),
    brent_crude_usd_bbl     DECIMAL(8,2),
    mom_change_pct          DECIMAL(7,2),
    yoy_change_pct          DECIMAL(7,2),
    load_timestamp          DATETIME2 DEFAULT SYSUTCDATETIME()
);
GO

-- ============================================================
-- DATA WAREHOUSE DIMENSION TABLES
-- ============================================================
DROP TABLE IF EXISTS dw.DimCountry;
CREATE TABLE dw.DimCountry (
    country_key             INT IDENTITY(1,1) PRIMARY KEY,
    iso3                    CHAR(3)         NOT NULL UNIQUE,
    country_name            NVARCHAR(100)   NOT NULL,
    region                  NVARCHAR(100),
    sub_region              NVARCHAR(100),
    is_asian                BIT             DEFAULT 0,
    local_currency          NVARCHAR(10),
    oil_import_dependency_pct DECIMAL(5,1),
    refinery_capacity_kbpd  INT,
    avg_monthly_income_usd  DECIMAL(10,2),
    created_at              DATETIME2       DEFAULT SYSUTCDATETIME()
);

DROP TABLE IF EXISTS dw.DimDate;
CREATE TABLE dw.DimDate (
    date_key        INT PRIMARY KEY,   -- YYYYMMDD
    full_date       DATE NOT NULL,
    year            SMALLINT,
    quarter         TINYINT,
    month           TINYINT,
    month_name      NVARCHAR(20),
    week_of_year    TINYINT,
    day_of_month    TINYINT,
    day_name        NVARCHAR(20),
    is_weekend      BIT
);

DROP TABLE IF EXISTS dw.DimSubsidyPolicy;
CREATE TABLE dw.DimSubsidyPolicy (
    policy_key                  INT IDENTITY(1,1) PRIMARY KEY,
    iso3                        CHAR(3)         NOT NULL,
    subsidy_type                NVARCHAR(50),
    gasoline_subsidized         BIT,
    diesel_subsidized           BIT,
    annual_subsidy_cost_bn_usd  DECIMAL(8,2),
    subsidy_pct_gdp             DECIMAL(5,2),
    pricing_mechanism           NVARCHAR(200),
    regulator                   NVARCHAR(50),
    last_price_change           DATE,
    effective_from              DATE,
    CONSTRAINT FK_SubsidyCountry FOREIGN KEY (iso3) REFERENCES dw.DimCountry(iso3)
);

-- ============================================================
-- FACT TABLES
-- ============================================================
DROP TABLE IF EXISTS dw.FactFuelPrices;
CREATE TABLE dw.FactFuelPrices (
    price_key               INT IDENTITY(1,1) PRIMARY KEY,
    date_key                INT             NOT NULL,
    country_key             INT             NOT NULL,
    gasoline_usd_per_liter  DECIMAL(6,3),
    diesel_usd_per_liter    DECIMAL(6,3),
    lpg_usd_per_kg          DECIMAL(6,3),
    avg_fuel_usd            DECIMAL(6,3),
    gasoline_local_price    DECIMAL(12,4),
    diesel_local_price      DECIMAL(12,4),
    fuel_affordability_index DECIMAL(8,2),
    gasoline_pct_daily_wage  DECIMAL(6,2),
    ev_adoption_pct         DECIMAL(5,2),
    co2_transport_mt        DECIMAL(10,2),
    CONSTRAINT FK_PriceDate    FOREIGN KEY (date_key)    REFERENCES dw.DimDate(date_key),
    CONSTRAINT FK_PriceCountry FOREIGN KEY (country_key) REFERENCES dw.DimCountry(country_key)
);

DROP TABLE IF EXISTS dw.FactCrudeOil;
CREATE TABLE dw.FactCrudeOil (
    crude_key               INT IDENTITY(1,1) PRIMARY KEY,
    year                    SMALLINT        NOT NULL UNIQUE,
    brent_avg_usd_bbl       DECIMAL(8,2),
    wti_avg_usd_bbl         DECIMAL(8,2),
    avg_price_usd_bbl       DECIMAL(8,2),
    brent_wti_spread        DECIMAL(7,2),
    brent_yoy_change_pct    DECIMAL(7,2),
    wti_yoy_change_pct      DECIMAL(7,2),
    key_event               NVARCHAR(200)
);

DROP TABLE IF EXISTS dw.FactTaxPolicy;
CREATE TABLE dw.FactTaxPolicy (
    tax_key                 INT IDENTITY(1,1) PRIMARY KEY,
    country_key             INT             NOT NULL,
    gasoline_tax_pct        DECIMAL(5,1),
    diesel_tax_pct          DECIMAL(5,1),
    vat_pct                 DECIMAL(5,1),
    excise_usd_per_liter    DECIMAL(6,3),
    total_tax_usd_per_liter DECIMAL(6,3),
    carbon_tax_active       BIT,
    tax_burden_category     NVARCHAR(20),
    CONSTRAINT FK_TaxCountry FOREIGN KEY (country_key) REFERENCES dw.DimCountry(country_key)
);

DROP TABLE IF EXISTS dw.FactMonthlyTrend;
CREATE TABLE dw.FactMonthlyTrend (
    trend_key               INT IDENTITY(1,1) PRIMARY KEY,
    date_key                INT             NOT NULL,
    country_key             INT             NOT NULL,
    gasoline_usd_per_liter  DECIMAL(6,3),
    brent_crude_usd_bbl     DECIMAL(8,2),
    mom_change_pct          DECIMAL(7,2),
    yoy_change_pct          DECIMAL(7,2),
    CONSTRAINT FK_TrendDate    FOREIGN KEY (date_key)    REFERENCES dw.DimDate(date_key),
    CONSTRAINT FK_TrendCountry FOREIGN KEY (country_key) REFERENCES dw.DimCountry(country_key)
);
GO

-- ============================================================
-- POPULATE DimDate (2015-2026)
-- ============================================================
;WITH DateCTE AS (
    SELECT CAST('2015-01-01' AS DATE) AS d
    UNION ALL
    SELECT DATEADD(DAY, 1, d) FROM DateCTE WHERE d < '2026-12-31'
)
INSERT INTO dw.DimDate
SELECT
    CAST(FORMAT(d,'yyyyMMdd') AS INT)   AS date_key,
    d                                   AS full_date,
    YEAR(d)                             AS year,
    DATEPART(QUARTER, d)                AS quarter,
    MONTH(d)                            AS month,
    DATENAME(MONTH, d)                  AS month_name,
    DATEPART(WEEK, d)                   AS week_of_year,
    DAY(d)                              AS day_of_month,
    DATENAME(WEEKDAY, d)                AS day_name,
    CASE WHEN DATEPART(WEEKDAY,d) IN (1,7) THEN 1 ELSE 0 END AS is_weekend
FROM DateCTE
OPTION (MAXRECURSION 5000);
GO

-- ============================================================
-- ETL STORED PROCEDURES
-- ============================================================

-- SP: Load countries from staging
CREATE OR ALTER PROCEDURE dw.usp_LoadDimCountry
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dw.DimCountry AS tgt
    USING (
        SELECT DISTINCT
            g.iso3,
            g.country        AS country_name,
            g.region,
            a.sub_region,
            g.is_asian,
            g.local_currency,
            a.oil_import_dependency_pct,
            a.refinery_capacity_kbpd,
            a.avg_monthly_income_usd
        FROM staging.GlobalFuelPrices g
        LEFT JOIN staging.AsiaFuelDetailed a ON g.iso3 = a.iso3
    ) AS src ON tgt.iso3 = src.iso3
    WHEN MATCHED THEN UPDATE SET
        tgt.country_name              = src.country_name,
        tgt.region                    = src.region,
        tgt.sub_region                = src.sub_region,
        tgt.oil_import_dependency_pct = src.oil_import_dependency_pct,
        tgt.refinery_capacity_kbpd    = src.refinery_capacity_kbpd,
        tgt.avg_monthly_income_usd    = src.avg_monthly_income_usd
    WHEN NOT MATCHED THEN INSERT
        (iso3, country_name, region, sub_region, is_asian, local_currency,
         oil_import_dependency_pct, refinery_capacity_kbpd, avg_monthly_income_usd)
    VALUES
        (src.iso3, src.country_name, src.region, src.sub_region, src.is_asian, src.local_currency,
         src.oil_import_dependency_pct, src.refinery_capacity_kbpd, src.avg_monthly_income_usd);

    PRINT 'DimCountry loaded: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows affected';
END;
GO

-- SP: Load fact fuel prices
CREATE OR ALTER PROCEDURE dw.usp_LoadFactFuelPrices
AS
BEGIN
    SET NOCOUNT ON;

    -- Truncate and reload (full snapshot)
    TRUNCATE TABLE dw.FactFuelPrices;

    INSERT INTO dw.FactFuelPrices
    (date_key, country_key, gasoline_usd_per_liter, diesel_usd_per_liter,
     lpg_usd_per_kg, avg_fuel_usd, gasoline_local_price, diesel_local_price,
     fuel_affordability_index, gasoline_pct_daily_wage, ev_adoption_pct, co2_transport_mt)
    SELECT
        CAST(FORMAT(g.price_date,'yyyyMMdd') AS INT) AS date_key,
        c.country_key,
        g.gasoline_usd_per_liter,
        g.diesel_usd_per_liter,
        a.lpg_usd_per_kg,
        g.avg_fuel_usd,
        g.gasoline_local_price,
        g.diesel_local_price,
        a.fuel_affordability_index,
        a.gasoline_pct_daily_wage,
        a.ev_adoption_pct,
        a.co2_transport_mt
    FROM staging.GlobalFuelPrices g
    JOIN dw.DimCountry c ON g.iso3 = c.iso3
    LEFT JOIN staging.AsiaFuelDetailed a ON g.iso3 = a.iso3;

    PRINT 'FactFuelPrices loaded: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows';
END;
GO

-- SP: Load crude oil facts
CREATE OR ALTER PROCEDURE dw.usp_LoadFactCrudeOil
AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE dw.FactCrudeOil;

    INSERT INTO dw.FactCrudeOil
    SELECT year, brent_avg_usd_bbl, wti_avg_usd_bbl, avg_price_usd_bbl,
           brent_wti_spread, brent_yoy_change_pct, wti_yoy_change_pct, key_event
    FROM staging.CrudeOilAnnual;

    PRINT 'FactCrudeOil loaded: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows';
END;
GO

-- SP: Load monthly trends
CREATE OR ALTER PROCEDURE dw.usp_LoadFactMonthlyTrend
AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE dw.FactMonthlyTrend;

    INSERT INTO dw.FactMonthlyTrend
    (date_key, country_key, gasoline_usd_per_liter, brent_crude_usd_bbl, mom_change_pct, yoy_change_pct)
    SELECT
        CAST(FORMAT(t.date,'yyyyMMdd') AS INT),
        c.country_key,
        t.gasoline_usd_per_liter,
        t.brent_crude_usd_bbl,
        t.mom_change_pct,
        t.yoy_change_pct
    FROM staging.PriceTrendMonthly t
    JOIN dw.DimCountry c ON t.country = c.country_name;

    PRINT 'FactMonthlyTrend loaded: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows';
END;
GO

-- SP: Master ETL orchestration
CREATE OR ALTER PROCEDURE dw.usp_RunFullETL
AS
BEGIN
    BEGIN TRY
        EXEC dw.usp_LoadDimCountry;
        EXEC dw.usp_LoadFactFuelPrices;
        EXEC dw.usp_LoadFactCrudeOil;
        EXEC dw.usp_LoadFactMonthlyTrend;
        PRINT 'ETL complet avec succès';
    END TRY
    BEGIN CATCH
        PRINT 'Erreur ETL: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- REPORTING VIEWS (couche rpt - utilisée par Power BI)
-- ============================================================

CREATE OR ALTER VIEW rpt.vw_GlobalPriceSnapshot AS
SELECT
    c.country_name,
    c.region,
    c.sub_region,
    c.iso3,
    f.gasoline_usd_per_liter,
    f.diesel_usd_per_liter,
    f.lpg_usd_per_kg,
    f.avg_fuel_usd,
    f.fuel_affordability_index,
    f.gasoline_pct_daily_wage,
    f.ev_adoption_pct,
    f.co2_transport_mt,
    c.avg_monthly_income_usd,
    c.oil_import_dependency_pct,
    d.full_date                 AS price_date,
    -- Benchmarks
    AVG(f.gasoline_usd_per_liter) OVER ()               AS global_avg_gasoline,
    AVG(f.gasoline_usd_per_liter) OVER (PARTITION BY c.region) AS region_avg_gasoline,
    RANK() OVER (ORDER BY f.gasoline_usd_per_liter DESC) AS rank_gasoline_desc
FROM dw.FactFuelPrices f
JOIN dw.DimCountry c ON f.country_key = c.country_key
JOIN dw.DimDate d    ON f.date_key    = d.date_key;
GO

CREATE OR ALTER VIEW rpt.vw_SubsidyAnalysis AS
SELECT
    c.country_name,
    c.region,
    s.subsidy_type,
    s.gasoline_subsidized,
    s.diesel_subsidized,
    s.annual_subsidy_cost_bn_usd,
    s.subsidy_pct_gdp,
    s.pricing_mechanism,
    s.regulator,
    f.gasoline_usd_per_liter,
    -- Calcul du coût par litre comparé au prix marché
    CASE WHEN s.gasoline_subsidized = 1
         THEN 1.50 - f.gasoline_usd_per_liter   -- estimation marché ~1.50
         ELSE 0 END                              AS estimated_subsidy_per_liter
FROM dw.DimSubsidyPolicy s
JOIN dw.DimCountry c ON s.iso3 = c.iso3
JOIN dw.FactFuelPrices f ON c.country_key = f.country_key;
GO

CREATE OR ALTER VIEW rpt.vw_TaxBurdenComparison AS
SELECT
    c.country_name,
    c.region,
    t.gasoline_tax_pct,
    t.diesel_tax_pct,
    t.vat_pct,
    t.excise_usd_per_liter,
    t.total_tax_usd_per_liter,
    t.carbon_tax_active,
    t.tax_burden_category,
    f.gasoline_usd_per_liter,
    -- Part de la taxe dans le prix
    CASE WHEN f.gasoline_usd_per_liter > 0
         THEN ROUND(t.total_tax_usd_per_liter / f.gasoline_usd_per_liter * 100, 1)
         ELSE 0 END AS tax_share_of_price_pct
FROM dw.FactTaxPolicy t
JOIN dw.DimCountry c ON t.country_key = c.country_key
JOIN dw.FactFuelPrices f ON c.country_key = f.country_key;
GO

CREATE OR ALTER VIEW rpt.vw_PriceTrendByCountry AS
SELECT
    d.full_date,
    d.year,
    d.month,
    d.month_name,
    d.quarter,
    c.country_name,
    c.region,
    mt.gasoline_usd_per_liter,
    mt.brent_crude_usd_bbl,
    mt.mom_change_pct,
    mt.yoy_change_pct,
    -- 3-month moving average
    AVG(mt.gasoline_usd_per_liter) OVER (
        PARTITION BY c.country_name
        ORDER BY d.date_key
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS gasoline_3m_ma
FROM dw.FactMonthlyTrend mt
JOIN dw.DimCountry c ON mt.country_key = c.country_key
JOIN dw.DimDate d     ON mt.date_key    = d.date_key;
GO

CREATE OR ALTER VIEW rpt.vw_CrudeOilTrend AS
SELECT
    year,
    brent_avg_usd_bbl,
    wti_avg_usd_bbl,
    avg_price_usd_bbl,
    brent_wti_spread,
    brent_yoy_change_pct,
    wti_yoy_change_pct,
    key_event,
    CASE
        WHEN brent_yoy_change_pct > 20  THEN 'Forte hausse'
        WHEN brent_yoy_change_pct > 5   THEN 'Hausse modérée'
        WHEN brent_yoy_change_pct < -20 THEN 'Forte baisse'
        WHEN brent_yoy_change_pct < -5  THEN 'Baisse modérée'
        ELSE 'Stable'
    END AS price_trend_label
FROM dw.FactCrudeOil;
GO

-- ============================================================
-- UTILITY QUERIES (exemples d'analyse)
-- ============================================================

-- Top 10 carburant le plus cher par région
SELECT TOP 10
    country_name, region, gasoline_usd_per_liter,
    rank_gasoline_desc AS world_rank
FROM rpt.vw_GlobalPriceSnapshot
ORDER BY gasoline_usd_per_liter DESC;

-- Corrélation prix carburant vs revenu moyen
SELECT country_name, avg_monthly_income_usd,
       gasoline_usd_per_liter, fuel_affordability_index,
       ROUND(gasoline_usd_per_liter / NULLIF(avg_monthly_income_usd,0) * 100, 3)
           AS fuel_cost_pct_monthly_income
FROM rpt.vw_GlobalPriceSnapshot
WHERE avg_monthly_income_usd IS NOT NULL
ORDER BY fuel_cost_pct_monthly_income DESC;

-- Coût total des subventions par région
SELECT c.region,
       COUNT(*) AS subsidized_countries,
       SUM(s.annual_subsidy_cost_bn_usd) AS total_subsidy_bn_usd,
       AVG(s.subsidy_pct_gdp) AS avg_subsidy_pct_gdp
FROM dw.DimSubsidyPolicy s
JOIN dw.DimCountry c ON s.iso3 = c.iso3
WHERE s.gasoline_subsidized = 1 OR s.diesel_subsidized = 1
GROUP BY c.region
ORDER BY total_subsidy_bn_usd DESC;
