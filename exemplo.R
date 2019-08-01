library(reticulate)
sagemaker <- import('sagemaker')
session <- sagemaker$Session()
bucket <- session$default_bucket()
role_arn <- session$expand_role('<nome-da-role>') # Role com permissao no Sage Maker e S3

######################################################

# Download Data
library(readr)
data_file <- 'https://archive.ics.uci.edu/ml/machine-learning-databases/abalone/abalone.data'
abalone <- read_csv(file = data_file, col_names = FALSE)
names(abalone) <- c('sex', 'length', 'diameter', 'height', 'whole_weight', 'shucked_weight', 'viscera_weight', 'shell_weight', 'rings')
head(abalone)

abalone$sex <- as.factor(abalone$sex)
summary(abalone)

library(ggplot2)
ggplot(abalone, aes(x = height, y = rings, color = sex)) + geom_point() + geom_jitter()

library(dplyr)
abalone <- abalone %>%
  filter(height != 0)

######################################################

abalone <- abalone %>%
  mutate(female = as.integer(ifelse(sex == 'F', 1, 0)),
         male = as.integer(ifelse(sex == 'M', 1, 0)),
         infant = as.integer(ifelse(sex == 'I', 1, 0))) %>%
  select(-sex)
abalone <- abalone %>%
  select(rings:infant, length:shell_weight)
head(abalone)

# Quebrando os dados 70% treino / 30% test e validacao
abalone_train <- abalone %>%
  sample_frac(size = 0.7)
abalone <- anti_join(abalone, abalone_train)
abalone_test <- abalone %>%
  sample_frac(size = 0.5)
abalone_valid <- anti_join(abalone, abalone_test)

write_csv(abalone_train, 'abalone_train.csv', col_names = FALSE)
write_csv(abalone_valid, 'abalone_valid.csv', col_names = FALSE)
write_csv(abalone_test, 'abalone_test.csv', col_names = FALSE)

#Upload S3
s3_train <- session$upload_data(path = 'abalone_train.csv', 
                                bucket = bucket, 
                                key_prefix = 'data')
s3_valid <- session$upload_data(path = 'abalone_valid.csv', 
                                bucket = bucket, 
                                key_prefix = 'data')
s3_test <- session$upload_data(path = 'abalone_test.csv', 
                                bucket = bucket, 
                                key_prefix = 'data')

# Load from S3
s3_train_input <- sagemaker$s3_input(s3_data = s3_train,
                                     content_type = 'csv')
s3_valid_input <- sagemaker$s3_input(s3_data = s3_valid,
                                     content_type = 'csv')
######################################################

registry <- sagemaker$amazon$amazon_estimator$registry(session$boto_region_name, algorithm='xgboost')
container <- paste(registry, '/xgboost:latest', sep='')

# Sage Maker estimator
s3_output <- paste0('s3://', bucket, '/output')
estimator <- sagemaker$estimator$Estimator(image_name = container,
                                           role = role_arn,
                                           train_instance_count = 1L,
                                           train_instance_type = 'ml.m5.large',
                                           train_volume_size = 30L,
                                           train_max_run = 3600L,
                                           input_mode = 'File',
                                           output_path = s3_output,
                                           output_kms_key = NULL,
                                           base_job_name = NULL,
                                           sagemaker_session = NULL)

# Cria o training job
estimator$set_hyperparameters(num_round = 100L)
job_name <- paste('sagemaker-train-xgboost', format(Sys.time(), '%H-%M-%S'), sep = '-')
input_data <- list('train' = s3_train_input,
                   'validation' = s3_valid_input)
estimator$fit(inputs = input_data,
              job_name = job_name)

estimator$model_data
######################################################
# Deploy
model_endpoint <- estimator$deploy(initial_instance_count = 1L,
                                   instance_type = 'ml.t2.medium')

######################################################
# Predições
model_endpoint$content_type <- 'text/csv'
model_endpoint$serializer <- sagemaker$predictor$csv_serializer

abalone_test <- abalone_test[-1]
num_predict_rows <- 500
test_sample <- as.matrix(abalone_test[1:num_predict_rows, ])
dimnames(test_sample)[[2]] <- NULL

library(stringr)
predictions <- model_endpoint$predict(test_sample)
predictions <- str_split(predictions, pattern = ',', simplify = TRUE)
predictions <- as.numeric(predictions)

abalone_test <- cbind(predicted_rings = predictions, 
                      abalone_test[1:num_predict_rows, ])
head(abalone_test)
abalone_test
######################################################
# Delete endpoint
session$delete_endpoint(model_endpoint$endpoint)