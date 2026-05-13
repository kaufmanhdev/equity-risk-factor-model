# exploration.R
# EDA & Visualizations


library(tidyverse)
library(GGally)
library(scales)
library(cowplot)

dir.create("plots", showWarnings = FALSE)

df <- read_csv("data/processed/sp500_clean.csv", show_col_types = FALSE) %>%
  mutate(sector = as.factor(sector))


summary(df %>% select(-symbol, -sector))
df %>% count(sector, sort = TRUE) %>% print(n = Inf)


# response variable distribution

p1 <- ggplot(df, aes(x = volatility_1yr)) +
  geom_histogram(bins = 40, fill = "#2C3E7A", color = "white", alpha = 0.85) +
  geom_vline(aes(xintercept = median(volatility_1yr)),
             color = "#E84040", linetype = "dashed", linewidth = 0.8) +
  labs(
    title    = "Distribution of 1-Year Realized Volatility",
    subtitle = "Red dashed line = median",
    x        = "Annualized Volatility",
    y        = "Count"
  ) +
  scale_x_continuous(labels = percent_format()) +
  theme_minimal(base_size = 13)

ggsave("plots/volatility_distribution.png", p1, width = 8, height = 5, dpi = 150)



# volatility by sector

sector_order <- df %>%
  group_by(sector) %>%
  summarise(med = median(volatility_1yr)) %>%
  arrange(desc(med)) %>%
  pull(sector)

p2 <- df %>%
  mutate(sector = factor(sector, levels = sector_order)) %>%
  ggplot(aes(x = sector, y = volatility_1yr, fill = sector)) +
  geom_boxplot(alpha = 0.8, outlier.size = 0.8, outlier.alpha = 0.4) +
  labs(
    title = "1-Year Realized Volatility by GICS Sector",
    x     = NULL,
    y     = "Annualized Volatility"
  ) +
  scale_y_continuous(labels = percent_format()) +
  scale_fill_brewer(palette = "Set3") +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x  = element_text(angle = 45, hjust = 1, size = 11),
    legend.position = "none",
    plot.margin  = margin(10, 10, 40, 10)
  )

ggsave("plots/volatility_by_sector.png", p2, width = 12, height = 7, dpi = 150)



# scatter plots: predictors vs volatility

predictors <- c("log_market_cap", "beta", "debt_equity",
                "pe_ratio", "revenue_growth")

pred_labels <- c(
  log_market_cap  = "Log Market Cap",
  beta            = "Beta (1-Year)",
  debt_equity     = "Debt-to-Equity",
  pe_ratio        = "P/E Ratio",
  revenue_growth  = "Revenue Growth"
)

plots_list <- map(predictors, function(var) {
  ggplot(df, aes(x = .data[[var]], y = volatility_1yr)) +
    geom_point(alpha = 0.3, size = 0.9, color = "#2C3E7A") +
    geom_smooth(method = "lm", se = TRUE, color = "#E84040", linewidth = 0.8) +
    labs(
      title = paste("Volatility vs", pred_labels[var]),
      x     = pred_labels[var],
      y     = "Annualized Volatility"
    ) +
    scale_y_continuous(labels = percent_format()) +
    theme_minimal(base_size = 11)
})

scatter_grid <- plot_grid(plotlist = plots_list, ncol = 2,
                          align = "hv", padding = unit(0.5, "cm"))
ggsave("plots/scatter_predictors.png", scatter_grid,
       width = 12, height = 10, dpi = 150)



# correlation matrix

p3 <- df %>%
  select(volatility_1yr, log_market_cap, beta,
         debt_equity, pe_ratio, revenue_growth) %>%
  ggpairs(
    columnLabels = c("Volatility", "Log Mkt Cap", "Beta",
                     "D/E", "P/E", "Rev Growth"),
    upper = list(continuous = wrap("cor", size = 3.5)),
    lower = list(continuous = wrap("points", alpha = 0.2, size = 0.5)),
    diag  = list(continuous = wrap("densityDiag", fill = "#2C3E7A", alpha = 0.6))
  ) +
  theme_minimal(base_size = 10) +
  labs(title = "Correlation Matrix - Continuous Variables")

ggsave("plots/correlation_matrix.png", p3, width = 14, height = 13, dpi = 150)
