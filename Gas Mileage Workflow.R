# Gas Mileage Workflow

# update data file with new observations
source("clean_gas_data.R")

# run MCMC
source("mcmc_sampler.R")
library("tictoc")

gas_data <- read_csv("gas_dataset.csv", show_col_types = FALSE) |>
  mutate(car = if_else(car == "Elantra", 1, 2))

y <- gas_data$mpg

groups <- gas_data$car

W <- gas_data |> select(-mpg, -car) |> as.matrix()

tic()
samples <- gibbs_sampler(W, y, groups)
toc()
samples$alpha |> colMeans() |> round(digits = 3)
samples$delta |> colMeans() |> round(digits = 3)
samples$sigma_2 |> mean()
samples$theta |> mean()

# Analyze Delta ----------------------------------------------------------

delta_samples <- samples$delta |> as_tibble() |>
  pivot_longer(cols = everything(), names_to = "gas_station", values_to = "mpg_change")

# histogram
delta_samples |>  
  ggplot() +
  geom_histogram(aes(x = mpg_change, fill = gas_station)) +
  facet_wrap(~gas_station) +
  theme(legend.position = "none")

# error bars
delta_samples |>
  group_by(gas_station) |>
  summarize(
    q05 = quantile(mpg_change, .05),
    qmedian = quantile(mpg_change, .5),
    q95 = quantile(mpg_change, .95)) |>
  arrange(desc(qmedian)) |>
  ggplot(aes(x = reorder(gas_station, qmedian), y = qmedian)) +
  geom_point() +
  geom_errorbar(aes(ymin = q05, ymax = q95), width = 0.2) +
  coord_flip() +
  labs(
    x = "Gas Station",
    y = "Estimated MPG Change",
    title = "Posterior Median and 90% CI")



