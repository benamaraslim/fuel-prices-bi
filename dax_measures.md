# DAX Measures — Rapport BI Prix des Carburants
# Power BI Desktop — Modèle FuelPricesBI

> Coller dans Power BI via **Modélisation → Nouvelle mesure** (ou importer le fichier .dax)

---

## TABLE : Measures (table de mesures dédiée)

### ── KPIs GLOBAUX ──

```dax
// Prix moyen mondial essence (USD/L)
[Avg Gasoline Global] =
    AVERAGEX(
        rpt_GlobalPriceSnapshot,
        rpt_GlobalPriceSnapshot[gasoline_usd_per_liter]
    )

// Prix médian mondial essence
[Median Gasoline Global] =
    MEDIANX(
        rpt_GlobalPriceSnapshot,
        rpt_GlobalPriceSnapshot[gasoline_usd_per_liter]
    )

// Nombre de pays suivis
[Countries Count] =
    DISTINCTCOUNT(rpt_GlobalPriceSnapshot[country_name])

// Prix maximum (pays le plus cher)
[Max Gasoline Price] =
    MAXX(rpt_GlobalPriceSnapshot, rpt_GlobalPriceSnapshot[gasoline_usd_per_liter])

// Prix minimum (pays le moins cher)
[Min Gasoline Price] =
    MINX(rpt_GlobalPriceSnapshot, rpt_GlobalPriceSnapshot[gasoline_usd_per_liter])

// Écart max-min
[Price Range] =
    [Max Gasoline Price] - [Min Gasoline Price]

// Pays le plus cher
[Most Expensive Country] =
    CALCULATE(
        FIRSTNONBLANK(rpt_GlobalPriceSnapshot[country_name], 1),
        TOPN(1, rpt_GlobalPriceSnapshot, rpt_GlobalPriceSnapshot[gasoline_usd_per_liter], DESC)
    )

// Pays le moins cher
[Cheapest Country] =
    CALCULATE(
        FIRSTNONBLANK(rpt_GlobalPriceSnapshot[country_name], 1),
        TOPN(1, rpt_GlobalPriceSnapshot, rpt_GlobalPriceSnapshot[gasoline_usd_per_liter], ASC)
    )
```

---

### ── SUBVENTIONS ──

```dax
// Coût total des subventions (Mrd USD)
[Total Subsidy Cost Bn USD] =
    SUMX(
        FILTER(rpt_SubsidyAnalysis, rpt_SubsidyAnalysis[annual_subsidy_cost_bn_usd] > 0),
        rpt_SubsidyAnalysis[annual_subsidy_cost_bn_usd]
    )

// Nombre de pays avec subvention active
[Subsidized Countries Count] =
    CALCULATE(
        COUNTROWS(rpt_SubsidyAnalysis),
        rpt_SubsidyAnalysis[gasoline_subsidized] = TRUE()
            || rpt_SubsidyAnalysis[diesel_subsidized] = TRUE()
    )

// % de pays subventionnant l'essence
[Pct Countries Subsidizing Gasoline] =
    DIVIDE(
        CALCULATE(COUNTROWS(rpt_SubsidyAnalysis),
            rpt_SubsidyAnalysis[gasoline_subsidized] = TRUE()),
        COUNTROWS(rpt_SubsidyAnalysis)
    )

// Subvention moyenne en % du PIB
[Avg Subsidy Pct GDP] =
    AVERAGEX(
        FILTER(rpt_SubsidyAnalysis, rpt_SubsidyAnalysis[subsidy_pct_gdp] > 0),
        rpt_SubsidyAnalysis[subsidy_pct_gdp]
    )

// Pays avec le coût de subvention le plus élevé
[Top Subsidy Country] =
    CALCULATE(
        FIRSTNONBLANK(rpt_SubsidyAnalysis[country_name], 1),
        TOPN(1, rpt_SubsidyAnalysis, rpt_SubsidyAnalysis[annual_subsidy_cost_bn_usd], DESC)
    )
```

---

### ── FISCALITÉ ──

```dax
// Taxe moyenne sur l'essence (%)
[Avg Gasoline Tax Pct] =
    AVERAGEX(rpt_TaxBurdenComparison, rpt_TaxBurdenComparison[gasoline_tax_pct])

// Total tax par litre (moyen)
[Avg Total Tax Per Liter] =
    AVERAGEX(rpt_TaxBurdenComparison, rpt_TaxBurdenComparison[total_tax_usd_per_liter])

// Pays avec taxe carbone active
[Countries With Carbon Tax] =
    CALCULATE(
        COUNTROWS(rpt_TaxBurdenComparison),
        rpt_TaxBurdenComparison[carbon_tax_active] = TRUE()
    )

// Répartition par catégorie de charge fiscale
[Countries Very High Tax] =
    CALCULATE(
        COUNTROWS(rpt_TaxBurdenComparison),
        rpt_TaxBurdenComparison[tax_burden_category] = "Very High"
    )

// Part de la taxe dans le prix (moyenne)
[Avg Tax Share Of Price Pct] =
    AVERAGEX(
        FILTER(rpt_TaxBurdenComparison, rpt_TaxBurdenComparison[gasoline_usd_per_liter] > 0),
        DIVIDE(
            rpt_TaxBurdenComparison[total_tax_usd_per_liter],
            rpt_TaxBurdenComparison[gasoline_usd_per_liter]
        )
    )
```

---

### ── PÉTROLE BRUT ──

```dax
// Prix Brent actuel (dernière année)
[Brent Latest Year] =
    CALCULATE(
        MAX(dw_FactCrudeOil[brent_avg_usd_bbl]),
        TOPN(1, dw_FactCrudeOil, dw_FactCrudeOil[year], DESC)
    )

// Prix WTI actuel
[WTI Latest Year] =
    CALCULATE(
        MAX(dw_FactCrudeOil[wti_avg_usd_bbl]),
        TOPN(1, dw_FactCrudeOil, dw_FactCrudeOil[year], DESC)
    )

// Spread Brent-WTI (dernière année)
[Brent WTI Spread Latest] =
    CALCULATE(
        MAX(dw_FactCrudeOil[brent_wti_spread]),
        TOPN(1, dw_FactCrudeOil, dw_FactCrudeOil[year], DESC)
    )

// Variation annuelle Brent (YoY %)
[Brent YoY Change Selected Year] =
    CALCULATE(
        AVERAGE(dw_FactCrudeOil[brent_yoy_change_pct]),
        ALLSELECTED(dw_FactCrudeOil[year])
    )

// Brent moyen 2015-2026
[Brent Avg All Years] =
    AVERAGEX(dw_FactCrudeOil, dw_FactCrudeOil[brent_avg_usd_bbl])

// Année pic du Brent
[Brent Peak Year] =
    CALCULATE(
        FIRSTNONBLANK(dw_FactCrudeOil[year], 1),
        TOPN(1, dw_FactCrudeOil, dw_FactCrudeOil[brent_avg_usd_bbl], DESC)
    )
```

---

### ── ASIE (ANALYSE APPROFONDIE) ──

```dax
// Indice d'accessibilité moyen (Asie)
[Avg Affordability Index Asia] =
    CALCULATE(
        AVERAGEX(
            rpt_GlobalPriceSnapshot,
            rpt_GlobalPriceSnapshot[fuel_affordability_index]
        ),
        rpt_GlobalPriceSnapshot[fuel_affordability_index] <> BLANK()
    )

// % journée de travail pour un litre d'essence
[Avg Gasoline Pct Daily Wage] =
    AVERAGEX(
        FILTER(rpt_GlobalPriceSnapshot,
            rpt_GlobalPriceSnapshot[gasoline_pct_daily_wage] <> BLANK()),
        rpt_GlobalPriceSnapshot[gasoline_pct_daily_wage]
    )

// Taux d'adoption VE moyen (pays asiatiques)
[Avg EV Adoption Pct Asia] =
    CALCULATE(
        AVERAGEX(
            rpt_GlobalPriceSnapshot,
            rpt_GlobalPriceSnapshot[ev_adoption_pct]
        ),
        rpt_GlobalPriceSnapshot[ev_adoption_pct] <> BLANK()
    )

// Total émissions CO2 transport (Asie)
[Total CO2 Transport MT] =
    SUMX(
        FILTER(rpt_GlobalPriceSnapshot,
            rpt_GlobalPriceSnapshot[co2_transport_mt] <> BLANK()),
        rpt_GlobalPriceSnapshot[co2_transport_mt]
    )

// Pays avec forte dépendance import pétrolier (>80%)
[Countries High Oil Import Dependency] =
    CALCULATE(
        COUNTROWS(rpt_GlobalPriceSnapshot),
        rpt_GlobalPriceSnapshot[oil_import_dependency_pct] >= 80
    )
```

---

### ── TENDANCES MENSUELLES ──

```dax
// Prix essence mensuel moyen (filtre par pays/date)
[Avg Monthly Gasoline Price] =
    AVERAGEX(
        rpt_PriceTrendByCountry,
        rpt_PriceTrendByCountry[gasoline_usd_per_liter]
    )

// Variation MoM (Month-over-Month) moyenne
[Avg MoM Change Pct] =
    AVERAGEX(
        FILTER(rpt_PriceTrendByCountry,
            rpt_PriceTrendByCountry[mom_change_pct] <> BLANK()),
        rpt_PriceTrendByCountry[mom_change_pct]
    )

// Variation YoY (Year-over-Year) moyenne
[Avg YoY Change Pct] =
    AVERAGEX(
        FILTER(rpt_PriceTrendByCountry,
            rpt_PriceTrendByCountry[yoy_change_pct] <> BLANK()),
        rpt_PriceTrendByCountry[yoy_change_pct]
    )

// Moyenne mobile 3 mois (via mesure)
[Gasoline 3M Moving Avg] =
    AVERAGEX(
        FILTER(
            ALL(rpt_PriceTrendByCountry),
            rpt_PriceTrendByCountry[country_name]
                = MAX(rpt_PriceTrendByCountry[country_name])
            && rpt_PriceTrendByCountry[full_date]
                >= EDATE(MAX(rpt_PriceTrendByCountry[full_date]), -2)
            && rpt_PriceTrendByCountry[full_date]
                <= MAX(rpt_PriceTrendByCountry[full_date])
        ),
        rpt_PriceTrendByCountry[gasoline_usd_per_liter]
    )

// Corrélation Brent / Prix pompe (approximation)
[Brent Pump Correlation Label] =
    VAR _corr = 0.87   -- valeur calculée via Python ETL
    RETURN "r = " & FORMAT(_corr, "0.00") & " (forte corrélation positive)"
```

---

### ── COMPARAISONS & BENCHMARKS ──

```dax
// Rang mondial du pays sélectionné (par prix essence)
[Country Gasoline World Rank] =
    RANKX(
        ALL(rpt_GlobalPriceSnapshot[country_name]),
        CALCULATE(AVERAGE(rpt_GlobalPriceSnapshot[gasoline_usd_per_liter])),
        ,
        DESC,
        DENSE
    )

// Comparaison vs moyenne régionale
[Vs Region Avg] =
    VAR _country_price = AVERAGE(rpt_GlobalPriceSnapshot[gasoline_usd_per_liter])
    VAR _region_avg    = CALCULATE(
            AVERAGE(rpt_GlobalPriceSnapshot[gasoline_usd_per_liter]),
            ALL(rpt_GlobalPriceSnapshot[country_name])
        )
    RETURN _country_price - _region_avg

// Label : au-dessus/en-dessous de la moyenne
[Vs Region Avg Label] =
    VAR _diff = [Vs Region Avg]
    RETURN
        IF(_diff > 0,
            "+" & FORMAT(_diff, "0.000") & " USD au-dessus de la moyenne régionale",
            FORMAT(_diff, "0.000") & " USD en-dessous de la moyenne régionale"
        )

// Prix normalisé (0-100, pour heat map)
[Gasoline Price Normalized] =
    DIVIDE(
        AVERAGE(rpt_GlobalPriceSnapshot[gasoline_usd_per_liter]) - [Min Gasoline Price],
        [Price Range]
    ) * 100
```

---

## PARAMÈTRES DE RAPPORT RECOMMANDÉS

| Paramètre DAX       | Valeur suggérée |
|---------------------|-----------------|
| Format monétaire    | `"$0.000 /L"`   |
| Format pourcentage  | `"0.0%"`        |
| Format Mrd USD      | `"#,##0.0 Mrd"` |
| Locale              | `fr-FR`         |

---

## RELATIONS RECOMMANDÉES (Power BI Modèle)

```
DimCountry[country_key]  →  FactFuelPrices[country_key]      (1:N)
DimCountry[country_key]  →  FactTaxPolicy[country_key]        (1:N)
DimCountry[country_key]  →  FactMonthlyTrend[country_key]     (1:N)
DimCountry[iso3]         →  DimSubsidyPolicy[iso3]            (1:N)
DimDate[date_key]        →  FactFuelPrices[date_key]          (1:N)
DimDate[date_key]        →  FactMonthlyTrend[date_key]        (1:N)
```
