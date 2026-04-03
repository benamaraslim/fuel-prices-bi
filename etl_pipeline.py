"""
ETL Pipeline - Prix des Carburants Mondiaux
Equivalent SSIS/Talend en Python
Charge les CSV -> SQL Server (staging) -> DW
"""

import os
import pandas as pd
import pyodbc
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError
import logging
from datetime import datetime

# ──────────────────────────────────────────────
# CONFIG
# ──────────────────────────────────────────────
DATA_DIR = r"C:\Users\slimb\Downloads\Compressed\archive_3"

SQL_SERVER   = "localhost"
DATABASE     = "FuelPricesBI"
CONN_STRING  = (
    f"mssql+pyodbc://{SQL_SERVER}/{DATABASE}"
    "?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"
)

CSV_MAP = {
    "staging.GlobalFuelPrices":   "global_fuel_prices.csv",
    "staging.AsiaFuelDetailed":   "asia_fuel_prices_detailed.csv",
    "staging.AsiaSubsidyTracker": "asia_subsidy_tracker.csv",
    "staging.CrudeOilAnnual":     "crude_oil_annual.csv",
    "staging.FuelTaxComparison":  "fuel_tax_comparison.csv",
    "staging.PriceTrendMonthly":  "price_trend_monthly.csv",
}

# ──────────────────────────────────────────────
# LOGGING
# ──────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(
            os.path.join(os.path.dirname(__file__), "etl_run.log"),
            encoding="utf-8"
        ),
    ],
)
log = logging.getLogger("fuel_etl")


# ──────────────────────────────────────────────
# EXTRACT
# ──────────────────────────────────────────────
def extract(filename: str) -> pd.DataFrame:
    path = os.path.join(DATA_DIR, filename)
    log.info(f"Extraction : {path}")
    df = pd.read_csv(path, low_memory=False)
    log.info(f"  {len(df):,} lignes, {df.shape[1]} colonnes")
    return df


# ──────────────────────────────────────────────
# TRANSFORM (par table)
# ──────────────────────────────────────────────
def transform_global_prices(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["price_date"] = pd.to_datetime(df["price_date"])
    df["is_asian"] = df["is_asian"].astype(bool)
    # Supprimer doublons
    df.drop_duplicates(subset=["iso3"], keep="last", inplace=True)
    # Assainissement des nuls
    for col in ["gasoline_usd_per_liter", "diesel_usd_per_liter", "avg_fuel_usd"]:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    log.info(f"  GlobalFuelPrices transformé : {len(df)} pays")
    return df


def transform_asia_detailed(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["price_date"] = pd.to_datetime(df["price_date"])
    df["fuel_subsidy_active"] = df["fuel_subsidy_active"].map(
        {True: True, False: False, "True": True, "False": False}
    ).fillna(False)
    numeric_cols = [
        "gasoline_usd_per_liter", "diesel_usd_per_liter", "lpg_usd_per_kg",
        "avg_monthly_income_usd", "fuel_affordability_index",
        "oil_import_dependency_pct", "ev_adoption_pct", "subsidy_cost_bn_usd",
        "co2_transport_mt", "gasoline_pct_daily_wage",
    ]
    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    log.info(f"  AsiaFuelDetailed transformé : {len(df)} pays")
    return df


def transform_subsidy_tracker(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["last_price_change"] = pd.to_datetime(df["last_price_change"])
    for col in ["gasoline_subsidized", "diesel_subsidized"]:
        df[col] = df[col].map(
            {True: True, False: False, "True": True, "False": False}
        ).fillna(False)
    df["annual_subsidy_cost_bn_usd"] = pd.to_numeric(
        df["annual_subsidy_cost_bn_usd"], errors="coerce"
    ).fillna(0)
    log.info(f"  AsiaSubsidyTracker transformé : {len(df)} pays")
    return df


def transform_crude_oil(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    numeric_cols = [
        "brent_avg_usd_bbl", "wti_avg_usd_bbl", "brent_yoy_change_pct",
        "wti_yoy_change_pct", "brent_wti_spread", "avg_price_usd_bbl",
    ]
    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    log.info(f"  CrudeOilAnnual transformé : {len(df)} années")
    return df


def transform_tax_comparison(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["carbon_tax_active"] = df["carbon_tax_active"].map(
        {True: True, False: False, "True": True, "False": False}
    ).fillna(False)
    numeric_cols = [
        "gasoline_tax_pct", "diesel_tax_pct", "vat_pct",
        "excise_usd_per_liter", "total_tax_usd_per_liter",
    ]
    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    log.info(f"  FuelTaxComparison transformé : {len(df)} pays")
    return df


def transform_monthly_trend(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["date"] = pd.to_datetime(df["date"])
    numeric_cols = [
        "gasoline_usd_per_liter", "brent_crude_usd_bbl",
        "mom_change_pct", "yoy_change_pct",
    ]
    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    df.drop_duplicates(subset=["date", "country"], inplace=True)
    log.info(f"  PriceTrendMonthly transformé : {len(df):,} lignes")
    return df


TRANSFORMERS = {
    "staging.GlobalFuelPrices":   transform_global_prices,
    "staging.AsiaFuelDetailed":   transform_asia_detailed,
    "staging.AsiaSubsidyTracker": transform_subsidy_tracker,
    "staging.CrudeOilAnnual":     transform_crude_oil,
    "staging.FuelTaxComparison":  transform_tax_comparison,
    "staging.PriceTrendMonthly":  transform_monthly_trend,
}


# ──────────────────────────────────────────────
# LOAD
# ──────────────────────────────────────────────
def load_to_staging(df: pd.DataFrame, table: str, engine) -> None:
    schema, tbl = table.split(".")
    log.info(f"Chargement staging.{tbl} ({len(df):,} lignes)...")
    df.to_sql(
        name=tbl,
        schema=schema,
        con=engine,
        if_exists="replace",
        index=False,
        chunksize=1000,
        method="multi",
    )
    log.info(f"  ✓ {table} chargé")


def run_dw_procedures(engine) -> None:
    procs = [
        "dw.usp_LoadDimCountry",
        "dw.usp_LoadFactFuelPrices",
        "dw.usp_LoadFactCrudeOil",
        "dw.usp_LoadFactMonthlyTrend",
    ]
    with engine.connect() as conn:
        for proc in procs:
            log.info(f"Exécution : EXEC {proc}")
            conn.execute(text(f"EXEC {proc}"))
            conn.commit()
    log.info("Toutes les procédures DW exécutées")


# ──────────────────────────────────────────────
# DATA QUALITY CHECKS
# ──────────────────────────────────────────────
def quality_checks(dataframes: dict) -> bool:
    log.info("=== Contrôles qualité ===")
    passed = True

    gfp = dataframes["staging.GlobalFuelPrices"]
    if gfp["iso3"].isna().any():
        log.error("GlobalFuelPrices: iso3 contient des nulls")
        passed = False
    if gfp["gasoline_usd_per_liter"].le(0).any():
        log.warning("GlobalFuelPrices: prix négatifs ou nuls détectés")

    asia = dataframes["staging.AsiaFuelDetailed"]
    if asia["fuel_affordability_index"].isna().sum() > 5:
        log.warning("AsiaFuelDetailed: trop de nulls dans affordability_index")

    crude = dataframes["staging.CrudeOilAnnual"]
    if crude["brent_avg_usd_bbl"].le(0).any():
        log.error("CrudeOilAnnual: prix Brent nuls/négatifs")
        passed = False

    trend = dataframes["staging.PriceTrendMonthly"]
    null_pct = trend["gasoline_usd_per_liter"].isna().mean() * 100
    if null_pct > 5:
        log.warning(f"PriceTrendMonthly: {null_pct:.1f}% de nulls gasoline")

    log.info("=== Contrôles qualité terminés ===")
    return passed


# ──────────────────────────────────────────────
# PYTHON ANALYSIS (couche analytique)
# ──────────────────────────────────────────────
def generate_analytics(dataframes: dict) -> None:
    log.info("=== Génération des analyses Python ===")

    gfp  = dataframes["staging.GlobalFuelPrices"]
    asia = dataframes["staging.AsiaFuelDetailed"]
    tax  = dataframes["staging.FuelTaxComparison"]
    sub  = dataframes["staging.AsiaSubsidyTracker"]
    crude = dataframes["staging.CrudeOilAnnual"]
    trend = dataframes["staging.PriceTrendMonthly"]

    # 1. Statistiques descriptives globales
    print("\n── PRIX MONDIAUX ──")
    print(gfp["gasoline_usd_per_liter"].describe().round(3))

    # 2. Moyennes par région
    print("\n── PRIX MOYEN PAR RÉGION ──")
    region_avg = (
        gfp.groupby("region")[["gasoline_usd_per_liter", "diesel_usd_per_liter"]]
        .mean()
        .round(3)
        .sort_values("gasoline_usd_per_liter", ascending=False)
    )
    print(region_avg.to_string())

    # 3. Top 5 plus chers / moins chers
    top5   = gfp.nlargest(5, "gasoline_usd_per_liter")[["country","gasoline_usd_per_liter"]]
    bot5   = gfp.nsmallest(5, "gasoline_usd_per_liter")[["country","gasoline_usd_per_liter"]]
    print("\n── TOP 5 PLUS CHERS ──");  print(top5.to_string(index=False))
    print("\n── TOP 5 MOINS CHERS ──"); print(bot5.to_string(index=False))

    # 4. Corrélation brut vs prix à la pompe
    trend_corr = (
        trend.groupby("date")[["gasoline_usd_per_liter", "brent_crude_usd_bbl"]]
        .mean()
    )
    corr_val = trend_corr.corr().loc[
        "gasoline_usd_per_liter", "brent_crude_usd_bbl"
    ]
    print(f"\n── CORRÉLATION BRENT / PRIX POMPE : r = {corr_val:.4f} ──")

    # 5. Coût total subventions
    total_sub = sub["annual_subsidy_cost_bn_usd"].sum()
    subsid_count = (sub["gasoline_subsidized"] | sub["diesel_subsidized"]).sum()
    print(f"\n── SUBVENTIONS ──")
    print(f"  Pays avec subventions : {subsid_count}")
    print(f"  Coût total            : {total_sub:.1f} Mrd USD")

    # 6. Évolution du Brent 2015→2026
    print("\n── ÉVOLUTION BRENT 2015-2026 ──")
    print(crude[["year","brent_avg_usd_bbl","brent_yoy_change_pct","key_event"]].to_string(index=False))

    # 7. Export résumé CSV
    summary_path = os.path.join(os.path.dirname(__file__), "analysis_summary.csv")
    summary = pd.DataFrame({
        "metric": [
            "global_avg_gasoline_usd", "global_median_gasoline_usd",
            "global_avg_diesel_usd", "countries_count",
            "subsidized_countries", "total_subsidy_bn_usd",
            "brent_2026_usd", "corr_brent_pump",
        ],
        "value": [
            round(gfp["gasoline_usd_per_liter"].mean(), 4),
            round(gfp["gasoline_usd_per_liter"].median(), 4),
            round(gfp["diesel_usd_per_liter"].mean(), 4),
            len(gfp),
            int(subsid_count),
            round(float(total_sub), 2),
            float(crude[crude["year"] == 2026]["brent_avg_usd_bbl"].values[0]),
            round(float(corr_val), 4),
        ],
        "generated_at": datetime.now().isoformat(),
    })
    summary.to_csv(summary_path, index=False)
    log.info(f"Résumé analytique exporté : {summary_path}")


# ──────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────
def main():
    start = datetime.now()
    log.info("=" * 60)
    log.info("DÉMARRAGE ETL - Prix des Carburants Mondiaux")
    log.info(f"Heure début : {start.strftime('%Y-%m-%d %H:%M:%S')}")
    log.info("=" * 60)

    try:
        engine = create_engine(CONN_STRING, fast_executemany=True)
        engine.connect().close()
        log.info("Connexion SQL Server OK")
    except Exception as e:
        log.error(f"Impossible de se connecter à SQL Server : {e}")
        log.info("Mode simulation (sans base de données)...")
        engine = None

    # EXTRACT + TRANSFORM
    dataframes = {}
    for table, filename in CSV_MAP.items():
        raw_df = extract(filename)
        transform_fn = TRANSFORMERS[table]
        dataframes[table] = transform_fn(raw_df)

    # QUALITY CHECKS
    quality_checks(dataframes)

    # LOAD
    if engine:
        for table, df in dataframes.items():
            try:
                load_to_staging(df, table, engine)
            except SQLAlchemyError as e:
                log.error(f"Erreur chargement {table}: {e}")

        try:
            run_dw_procedures(engine)
        except Exception as e:
            log.error(f"Erreur procédures DW : {e}")
    else:
        log.warning("Chargement SQL ignoré (pas de connexion)")

    # ANALYTICS
    generate_analytics(dataframes)

    elapsed = (datetime.now() - start).total_seconds()
    log.info(f"ETL terminé en {elapsed:.1f}s")


if __name__ == "__main__":
    main()
