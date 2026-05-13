# data_prep.R
# Equity Risk Factor Model: Data Loading & Preparation

# BEFORE RUNNING: Add Finnhub API key to .Renviron:

library(tidyverse)
library(tidyquant)
library(httr)
library(jsonlite)

# load Finnhub key from .Renviron
FINNHUB_KEY <- Sys.getenv("FINNHUB_API_KEY")
if (FINNHUB_KEY == "") stop("FINNHUB_API_KEY not found in .Renviron")


# pull S&P 500 tickers and sector classifications

cat("Fetching S&P 500 constituent list\n")
sp500_raw <- tq_index("SP500")

# remove malformed rows
sp500_raw <- sp500_raw %>%
  filter(
    !is.na(symbol),
    symbol != "-",
    nchar(symbol) >= 1,
    grepl("^[A-Z]", symbol)
  )

# tq_index() no longer populates sector - pull directly from Wikipedia

cat("Fetching sector classifications from Wikipedia\n")
library(rvest)
wiki_url <- "https://en.wikipedia.org/wiki/List_of_S%26P_500_companies"
sectors <- wiki_url %>%
  read_html() %>%
  html_table(fill = TRUE) %>%
  .[[1]] %>%
  select(symbol = Symbol, sector = `GICS Sector`)

sp500 <- sp500_raw %>%
  select(symbol) %>%
  inner_join(sectors, by = "symbol")

cat("Total tickers:", nrow(sp500), "\n")
cat("Sectors found:", n_distinct(sp500$sector), "\n")


# pull 1 year of daily price data (tidyquant / Yahoo Finance)

cache_prices <- "data/raw/sp500_prices.csv"
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)

if (!file.exists(cache_prices)) {
  cat("Fetching price data from Finhub (5-10 min)...\n")
  cat("Fancy elevator music?\n")

  prices_raw <- tq_get(sp500$symbol,
                       get            = "stock.prices",
                       from           = Sys.Date() - 365,
                       to             = Sys.Date(),
                       complete_cases = FALSE)

  write_csv(prices_raw, cache_prices)
  cat("Prices cached to:", cache_prices, "\n")

} else {
  cat("Loading cached prices from:", cache_prices, "\n")
  prices_raw <- read_csv(cache_prices, show_col_types = FALSE)
}

cat("Price rows loaded:", nrow(prices_raw), "\n")


# compute 1-year realized volatility

volatility <- prices_raw %>%
  group_by(symbol) %>%
  tq_transmute(select     = adjusted,
               mutate_fun = periodReturn,
               period     = "daily",
               type       = "log",
               col_rename = "log_return") %>%
  summarise(
    volatility_1yr = sd(log_return, na.rm = TRUE) * sqrt(252),
    n_obs          = sum(!is.na(log_return))
  ) %>%
  filter(n_obs >= 200)

cat("Volatility computed for", nrow(volatility), "tickers\n")



# pull fundamentals via Finnhub REST API

cache_fundamentals <- "data/raw/sp500_fundamentals.csv"

fetch_fundamentals <- function(ticker, key) {
  url <- paste0(
    "https://finnhub.io/api/v1/stock/metric?symbol=",
    ticker, "&metric=all&token=", key
  )
  tryCatch({
    resp    <- GET(url)
    metrics <- fromJSON(content(resp, "text", encoding = "UTF-8"))$metric
    tibble(
      symbol         = ticker,
      market_cap     = metrics$marketCapitalization      %||% NA_real_,
      pe_ratio       = metrics$peTTM                     %||% NA_real_,
      beta           = metrics$beta                      %||% NA_real_,
      revenue_growth = metrics$revenueGrowthTTMYoy       %||% NA_real_,
      debt_equity    = metrics$`totalDebt/totalEquityAnnual` %||% NA_real_
    )
  }, error = function(e) {
    tibble(symbol = ticker, market_cap = NA_real_, pe_ratio = NA_real_,
           beta = NA_real_, revenue_growth = NA_real_, debt_equity = NA_real_)
  })
}

`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0) a else b

if (!file.exists(cache_fundamentals)) {
  cat("Fetching fundamentals from Finnhub\n")
  cat("This will take appx. 10 minutes for 500 tickers\n")

  fundamentals <- map_dfr(sp500$symbol, function(sym) {
    result <- fetch_fundamentals(sym, FINNHUB_KEY)
    Sys.sleep(1.1)   # 60 req/min = 1 req per second, with buffer
    result
  })

  write_csv(fundamentals, cache_fundamentals)
  cat("Fundamentals cached to:", cache_fundamentals, "\n")

} else {
  cat("Loading cached fundamentals from:", cache_fundamentals, "\n")
  fundamentals <- read_csv(cache_fundamentals, show_col_types = FALSE)
}

cat("Fundamentals loaded for", nrow(fundamentals), "tickers\n")



# join all data sources

df <- sp500 %>%
  select(symbol, sector) %>%
  inner_join(volatility    %>% select(symbol, volatility_1yr), by = "symbol") %>%
  inner_join(fundamentals,                                      by = "symbol")

cat("Joined dataset:", nrow(df), "rows\n")


# clean and engineer features

df_clean <- df %>%

  drop_na(volatility_1yr, market_cap, pe_ratio, beta,
          debt_equity, revenue_growth, sector) %>%

  filter(
    volatility_1yr > 0,
    market_cap     > 0,
    pe_ratio       > 0,
    pe_ratio       < 200,
    debt_equity    >= 0,
    debt_equity    < 20,
    abs(revenue_growth) < 5
  ) %>%

  mutate(
    log_market_cap = log(market_cap),
    sector         = as.factor(sector)
  ) %>%

  select(symbol, sector, volatility_1yr, log_market_cap,
         beta, debt_equity, pe_ratio, revenue_growth)


cat("Clean dataset dimensions:", nrow(df_clean), "rows x",
    ncol(df_clean), "cols\n")
cat("Sector levels:\n")
print(table(df_clean$sector))


# save processed data

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
write_csv(df_clean, "data/processed/sp500_clean.csv")

