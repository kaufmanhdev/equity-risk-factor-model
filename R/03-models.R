# models.R
# (Four Linear Regression Models)


library(tidyverse)
library(broom)
library(car)      # vif()

df <- read_csv("data/processed/sp500_clean.csv", show_col_types = FALSE) %>%
  mutate(sector = as.factor(sector))

# Set reference sector
df$sector <- relevel(df$sector, ref = "Utilities")


# model 1 - baseline: market-level signals only
# establish a floor; beta is the textbook measure of systematic risk

model1 <- lm(volatility_1yr ~ log_market_cap + beta, data = df)

cat("MODEL 1: Baseline\n")
cat("Spec: volatility_1yr ~ log_market_cap + beta\n\n")
summary(model1)


# model 2 - add fundamental accounting ratios

model2 <- lm(volatility_1yr ~ log_market_cap + beta +
               debt_equity + pe_ratio,
             data = df)

cat("\nMODEL 2: + Fundamentals\n")
cat("Spec: volatility_1yr ~ log_market_cap + beta + debt_equity + pe_ratio\n\n")
summary(model2)

cat("\nVIF - Model 2:\n")
print(vif(model2))


# model 3 - add sector as a factor variable
# sector membership captures structural industry-level risk not
# explained by individual firm metrics

model3 <- lm(volatility_1yr ~ log_market_cap + beta +
               debt_equity + pe_ratio + sector,
             data = df)

cat("\nMODEL 3: + Sector (Factor)\n")
cat("Spec: volatility_1yr ~ log_market_cap + beta + debt_equity + pe_ratio + sector\n\n")
summary(model3)

cat("\nVIF - Model 3 (continuous terms only):\n")
print(vif(model3))

cat("\nSector Coefficients vs Utilities (reference):\n")
tidy(model3) %>%
  filter(str_detect(term, "sector")) %>%
  mutate(
    sector   = str_remove(term, "sector"),
    estimate = round(estimate, 4),
    p.value  = round(p.value, 4)
  ) %>%
  select(sector, estimate, p.value) %>%
  arrange(desc(estimate)) %>%
  print()


# model 4 - interaction: debt_equity * sector
# high D/E in Financials reflects normal business model (borrowing to lend);
# in Industrials the same ratio signals fragility

model4 <- lm(volatility_1yr ~ log_market_cap + beta +
               debt_equity * sector,
             data = df)

cat("\nMODEL 4: Interaction (D/E x Sector)\n")
cat("Spec: volatility_1yr ~ log_market_cap + beta + debt_equity * sector\n\n")
summary(model4)


# model comparison

comparison <- tibble(
  Model    = paste0("Model ", 1:4),
  Spec     = c(
    "~ log_market_cap + beta",
    "~ log_market_cap + beta + debt_equity + pe_ratio",
    "~ ... + sector",
    "~ ... + debt_equity * sector"
  ),
  Adj_R2   = c(
    summary(model1)$adj.r.squared,
    summary(model2)$adj.r.squared,
    summary(model3)$adj.r.squared,
    summary(model4)$adj.r.squared
  ),
  AIC      = c(AIC(model1), AIC(model2), AIC(model3), AIC(model4)),
  Num_Pred = c(2, 4, 4 + nlevels(df$sector) - 1,
               2 + nlevels(df$sector) * 2 - 1)
) %>%
  mutate(across(c(Adj_R2, AIC), ~round(., 4)))

cat("\nMODEL COMPARISON\n")
print(comparison)

# Save models for diagnostics.R and the .rmd report
saveRDS(list(model1     = model1,
             model2     = model2,
             model3     = model3,
             model4     = model4,
             comparison = comparison),
        file = "data/processed/models.rds")
