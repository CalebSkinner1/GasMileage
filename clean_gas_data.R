# cleaning gas data


# load packages, data ----------------------------------------------------
library("readxl")
library("tidyverse")
library("janitor")

gas <- read_excel("gas_data.xlsx", col_types = c("text", "text", "numeric", "numeric")) |>
  clean_names() |> group_by(car) |>
  mutate(
    index = row_number(),
    # compute gas mileage
    location = lead(location, 1),
    mpg = lead(miles/gallons, 1),
    m = lead(miles, 1),
    g = lead(gallons, 1)) |>
  ungroup() |> filter(!is.na(location)) |> 
  mutate(location = case_when(
    str_detect(location, "Love") ~ "Loves",
    location == "H-E-B" ~ "HEB",
    location == "Philips66" ~ "Phillips66",
    location == "Phillipps66" ~ "Phillips66",
    location == "Philipps66" ~ "Phillips66",
    .default = location)) |>
  pivot_wider(names_from = location, values_from = gallons) |>
  clean_names() |>
  select(-miles)

locations <- colnames(gas |> select(-car, -index, -mpg, -m, -g))

# compute tank composition -----------------------------------------------

composition <- gas |> filter(is.na(car)) |> select(car, index, all_of(locations))

compute_composition <- function(tbl, comp_tbl, idx, car_idx, tank_size = 14.0) {
  gallons <- tbl |> filter(car == car_idx, index == idx) |>
    select(all_of(locations)) |> rowSums(na.rm = TRUE)
  
  ct <- comp_tbl |> filter(car == car_idx, index == idx - 1) |>
    select(-car, -index) |>
    pivot_longer(cols = any_of(locations), names_to = "location", values_to = "composition")

  tbl |> filter(car == car_idx, index == idx) |> 
    mutate(across(all_of(locations), ~.x/tank_size)) |>
    select(all_of(locations)) |>
    pivot_longer(cols = all_of(locations), names_to = "location", values_to = "new_composition") |>
    left_join(ct, by = join_by(location)) |>
    mutate(composition = replace_na(composition*(14 - gallons)/14, 0) + replace_na(new_composition, 0)) |>
    select(location, composition) |>
    pivot_wider(names_from = location, values_from = composition) |>
    mutate(car = car_idx, index = idx) |>
    relocate(c(car, index)) |>
    bind_rows(comp_tbl) |>
    arrange(index)
}

compute_composition_wrapper <- function(tbl, comp_tbl, car_idx, tank_size = 14.0){
  e_idx <- tbl |> filter(car == car_idx) |> pull(index) |> max()
  for(i in 1:e_idx){
    comp_tbl <- compute_composition(tbl, comp_tbl, idx = i, car_idx = car_idx)
  }
  comp_tbl |> left_join(select(tbl, car, m, g, mpg, index), by = join_by(car, index)) |>
    relocate(c(m, g, mpg), .after = index)
}

# Elantra
elantra <- compute_composition_wrapper(gas, composition, "Elantra")

# CRV
crv <- compute_composition_wrapper(gas, composition, "CRV")

# Rogue
rogue <- compute_composition_wrapper(gas, composition, "Rogue", tank_size = 14.5)

data <- bind_rows(elantra, crv, rogue) |>
  rowwise() |> 
  mutate(tank = sum(c_across(all_of(locations)))) |>
  ungroup() |>
  filter(g > 8, tank > 0.99) |> # ensure 99% of tank is accounted for
  select(-index, -m, -g, -tank)

write_csv(data, "gas_dataset.csv")

