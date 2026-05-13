# Equity Risk Factor Model
### Statistical Methods – Final Project

A linear regression analysis predicting **annualized return volatility** for S&P 500 stocks using fundamental accounting ratios, market metrics, and sector classification. Built in RStudio as part of a Statistical Methods course.

---

## Project Overview

**Research question:** Can firm-level fundamentals and sector membership predict how volatile a stock's returns will be over the next year?

**Why this project:** Volatility is the foundational input to options pricing (Black-Scholes), Value-at-Risk models, and portfolio construction. Understanding which firm characteristics drive risk is core work in quantitative finance and asset management.

---

## Repository Structure

```
equity-risk-factor-model/
│
├── README.md
│
├── data/
│   ├── raw/
│   │   └── sp500_raw.csv          # Original dataset (untouched)
│   └── processed/
│       └── sp500_clean.csv        # After cleaning & feature engineering
│
├── R/
│   ├── 01_data_prep.R             # Load, clean, log-transform market cap
│   ├── 02_exploration.R           # Summary stats, EDA plots
│   ├── 03_models.R                # All four lm() model definitions
│   └── 04_diagnostics.R          # Residuals, AIC comparison, model selection
│
├── plots/
│   ├── volatility_by_sector.png
│   ├── correlation_matrix.png
│   ├── residuals_model3.png
│   └── model_comparison.png
│
├── report/
│   └── equity_risk_factor_model.Rmd        # R Markdown source -> knits to final PDF
│
└── output/
    └── equity_risk_factor_model.pdf        # Final submission
```

---

## Dataset

**Source:** Live data pulled programmatically via `tidyquant`

- **Constituents & sectors:** `tq_index("SP500")` -> current S&P 500 members and GICS sector classifications sourced from Wikipedia
- **Price history:** `tq_get(get = "stock.prices")` -> 1 year of daily adjusted closing prices from Yahoo Finance
- **Fundamentals:** `tq_get(get = "key.stats")` -> PE ratio, beta, market cap, debt/equity, revenue growth from Yahoo Finance

Data reflects the trailing 12 months as of the date `01_data_prep.R` is run. Raw API responses are cached to `data/raw/` - the fetch only runs once.


**Variables**

| `volatility_1yr` | Continuous | **Response (Y)** | Annualized std dev of daily returns over trailing 12 months |
| `log_market_cap` | Continuous | Predictor | Log-transformed market capitalization (reduces skew) |
| `beta_1yr` | Continuous | Predictor | 1-year rolling beta vs. S&P 500 |
| `debt_to_equity` | Continuous | Predictor | Total debt / shareholders' equity |
| `pe_ratio` | Continuous | Predictor | Price-to-earnings ratio |
| `revenue_growth` | Continuous | Predictor | Year-over-year revenue growth (%) |
| `sector` | **Factor** | Predictor | GICS sector classification (11 levels) |

---

## Models

Four models are built progressively, each motivated by a specific analytical question:

| 1 | `volatility ~ log_market_cap + beta_1yr` | Baseline: market-level signals only |
| 2 | `volatility ~ log_market_cap + beta_1yr + debt_to_equity + pe_ratio` | Add fundamental accounting ratios |
| 3 | `volatility ~ log_market_cap + beta_1yr + debt_to_equity + pe_ratio + sector` | Add sector as a factor variable |
| 4 | `volatility ~ log_market_cap + beta_1yr + debt_to_equity * sector` | Interaction: does leverage effect differ by sector? |

Model selection uses **Adjusted R²**, **AIC**, and **residual diagnostics** (Q-Q plot, scale-location, Cook's distance).

---

## How to Reproduce

### Requirements

- R (≥ 4.2.0)
- RStudio
- Packages: `tidyverse`, `tidyquant`, `GGally`, `car`, `broom`

Install all dependencies at once:

```r
install.packages(c("tidyverse", "tidyquant", "GGally", "car", "broom",
                   "cowplot", "scales", "knitr", "rmarkdown"))
```

### Run order

Execute scripts in numbered order from the `R/` directory:

```r
source("R/01-data_prep.R")
source("R/02-exploration.R")
source("R/03-models.R")
source("R/04-diagnostics.R")
```

### Render the report

Open `report/equity_risk_factor_model.Rmd` in RStudio and knit to PDF:

```r
rmarkdown::render("report/equity_risk_factor_model.Rmd", output_format = "pdf_document")
```

The output will be saved to `output/equity_risk_factor_model.pdf`.

---

## Key Findings (Summary)

- **Sector membership** is the single strongest categorical predictor - Technology and Consumer Discretionary stocks carry significantly higher baseline volatility than Utilities and Consumer Staples, holding other factors constant.
- **Leverage (D/E ratio)** amplifies volatility, but the magnitude differs meaningfully by sector — the interaction term in Model 4 captures this.
- **Beta**, as expected, is strongly significant across all models, but fundamental variables add incremental explanatory power beyond it.
- **Model 4** (`~ log_market_cap + beta + D/E + P/E + sector`) is selected as the best model based on lowest AIC and highest Adjusted R², with well-behaved residuals and no severe multicollinearity (VIF < 5 for all terms).

---

## Analytical Framework

This project decomposes stock volatility into three components:

1. **Market-wide (systematic) risk** - captured by beta and market cap
2. **Firm-specific (idiosyncratic) risk** - captured by leverage and valuation ratios
3. **Sector-level structural risk** - captured by the GICS sector factor

This maps directly to the **systematic vs. idiosyncratic risk** framework used in quantitative portfolio management.

---

## Author

**Herman Kaufman**  
Statistical Methods - Final Project
