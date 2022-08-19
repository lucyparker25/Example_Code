# Modelling the wetlands/ non wetlands using tidymodels
# Lucy Parker

# Libraries
library(tidyverse)
library(tidymodels)
library(bonsai) # required for lightgbm model *MUST LOAD*
library(tidypredict)
library(vip)

# File paths
featherfile <- list.files(file.path('D:', 'Projects', 'NG_mapping', 'data', 'data_tables', 'sampled_data_frames'), full.names = TRUE)[3]
plot_path <- file.path('D:', 'Projects', 'NG_mapping', 'output', 'model_diags', 'exploratory')

### Reading in tile data (tifs converted to data frames) and subsampling
# Reading in the feather file
tile_data <- arrow::read_feather(featherfile)

# Recoding target as factor
tile_data$wetland <- as.factor(tile_data$wetland)

# Randomly sampling 62.5k of each class per tile
tile_sample <- tile_data %>%
  group_by(wetland, tile) %>%
  slice_sample(n = 62500) %>%
  ungroup() %>%
  select(-c(tile, Conf))

### Splitting the data into test and train
# Creating a var to split the data by
data_split <- initial_split(tile_sample,
                            prop = 0.7,
                            strata = wetland)

# Splitting the data
sa_train <- data_split %>% training()
sa_test <- data_split %>% testing()


### Model Creation
# Creating the recipe
sa_recipe <- recipe(wetland ~ .,
                    data = sa_train) %>%
  update_role(x, y, new_role = "ID") %>%
  step_normalize(all_numeric(), -all_outcomes(), -x, -y) %>%
  step_zv(all_numeric(), -all_outcomes()) %>%
  step_scale(all_numeric(), -all_outcomes(), -x, -y)

summary(sa_recipe)

# Validation set
# using k-fold cross validation

# setting the seed
set.seed(305)

sa_folds <- vfold_cv(sa_train,
                     v = 10,
                     strata = wetland)


# Setting up the lightgbm model
sa_lgbm_spec <- boost_tree(mtry = tune(),
                           trees = tune(),
                           min_n = tune(),
                           learn_rate = tune(),
                           tree_depth = tune(),
                           loss_reduction = tune()) %>%
  set_engine("lightgbm") %>%
  set_mode("classification")


# Storing the workflow
sa_lgbm_wf <- workflow() %>%
  add_recipe(sa_recipe) %>%
  add_model(sa_lgbm_spec)

# lightgbm
lgbm_params <- extract_parameter_set_dials(sa_lgbm_spec)
lgbm_params <- lgbm_params %>%
  update(mtry = mtry(c(1, 27)))

# Tune the model using a Bayesian approach and asses model accuracy using the Kappa coefficient
sa_lgbm_tune <- sa_lgbm_wf %>%
  tune_bayes(resamples = sa_folds,
             initial = 10,
             iter = 75,
             param_info = lgbm_params,
             metrics = metric_set(kap, precision, f_meas, accuracy, recall, roc_auc, sens, spec),
             control = control_bayes(no_improve = 50, verbose = TRUE, uncertain = 10))


# Selecting the best model
sa_lgbm_best <- select_best(sa_lgbm_tune, metric = "kap")

# Saving the model
# Parsing
final_wf <- sa_lgbm_wf %>%
  finalize_workflow(sa_lgbm_best)

final_fit <- final_wf %>%
  last_fit(data_split,
           metrics = metric_set(kap, precision, f_meas, accuracy, recall, roc_auc, sens, spec))

saveRDS(final_wf, file.path('D:', 'Projects', 'NG_mapping', 'output', 'models', '1m_pix_wf.rds'))
saveRDS(final_fit, file.path('D:', 'Projects', 'NG_mapping', 'output', 'models', '1m_fit_wf.rds'))

