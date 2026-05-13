# diagnostics.R

library(tidyverse)
library(broom)
library(scales)
library(cowplot)

dir.create("plots", showWarnings = FALSE)

# Load saved models
models_list <- readRDS("data/processed/models.rds")
model1      <- models_list$model1
model2      <- models_list$model2
model3      <- models_list$model3
model4      <- models_list$model4
comparison  <- models_list$comparison


# diagnostic plots for model 3 and model 4

png("plots/residuals_model3.png", width = 1200, height = 1000, res = 130)
par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
plot(model3, which = 1, main = "Residuals vs Fitted - Model 3")
plot(model3, which = 2, main = "Q-Q Plot - Model 3")
plot(model3, which = 3, main = "Scale-Location - Model 3")
plot(model3, which = 5, main = "Residuals vs Leverage - Model 3")
dev.off()

png("plots/residuals_model4.png", width = 1200, height = 1000, res = 130)
par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
plot(model4, which = 1, main = "Residuals vs Fitted - Model 4")
plot(model4, which = 2, main = "Q-Q Plot - Model 4")
plot(model4, which = 3, main = "Scale-Location - Model 4")
plot(model4, which = 5, main = "Residuals vs Leverage - Model 4")
dev.off()


# model comparison plot (Adj R² and AIC)

p_adjr2 <- ggplot(comparison,
                  aes(x = Model, y = Adj_R2, fill = Model)) +
  geom_col(alpha = 0.85, width = 0.6) +
  geom_text(aes(label = round(Adj_R2, 3)),
            vjust = -0.4, size = 3.8) +
  scale_fill_brewer(palette = "Blues", direction = 1) +
  labs(title = "Adjusted R² by Model",
       x = NULL, y = "Adjusted R²") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

p_aic <- ggplot(comparison,
                aes(x = Model, y = AIC, fill = Model)) +
  geom_col(alpha = 0.85, width = 0.6) +
  geom_text(aes(label = round(AIC, 1)),
            vjust = -0.4, size = 3.8) +
  scale_fill_brewer(palette = "Reds", direction = 1) +
  labs(title = "AIC by Model (lower = better)",
       x = NULL, y = "AIC") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

comparison_plot <- plot_grid(p_adjr2, p_aic, ncol = 2)
ggsave("plots/model_comparison.png", comparison_plot,
       width = 10, height = 5, dpi = 150)


# influential observations - Cook's distance (Model 3)

augmented <- augment(model3)
threshold  <- 4 / nrow(augmented)

p_cooks <- ggplot(augmented, aes(x = seq_len(nrow(augmented)),
                                  y = .cooksd)) +
  geom_col(aes(fill = .cooksd > threshold), width = 0.8) +
  geom_hline(yintercept = threshold, color = "red",
             linetype = "dashed") +
  scale_fill_manual(values = c("FALSE" = "#AABCDE", "TRUE" = "#E84040"),
                    labels = c("Normal", "Influential")) +
  labs(
    title    = "Cook's Distance - Model 3",
    subtitle = paste0("Red dashed line = 4/n threshold (",
                      round(threshold, 5), ")"),
    x    = "Observation Index",
    y    = "Cook's Distance",
    fill = NULL
  ) +
  theme_minimal(base_size = 12)

ggsave("plots/cooks_distance_model3.png", p_cooks,
       width = 10, height = 5, dpi = 150)



cat("\nFINAL MODEL COMPARISON\n")
print(comparison)

best <- comparison %>% slice_max(Adj_R2, n = 1)
cat("\nSelected model:", best$Model, "\n")
cat("Spec:", best$Spec, "\n")
cat("Adjusted R²:", best$Adj_R2, "\n")
cat("AIC:", best$AIC, "\n")
