# Main script to call each step in the process to create stacked images ready for wetland prediction
# Lucy Parker

# Libraries
library(pacman)
p_load(tidyverse, sf, raster, terra, gdalUtilities, httr, readr, dplyr, stringr, moments, lubridate, devtools, rgee, googledrive, doParallel, foreach)

# File paths to pass through full script
storage_drive <- file.path('D:')
project_path <- file.path(storage_drive, 'Projects', 'NG_mapping')

scripts_path <- file.path(storage_drive, 'Projects', 'NG_mapping', 'code')
functions_path <- file.path(storage_drive, 'Projects', 'NG_mapping', 'code', 'functions')
basedir <- file.path(storage_drive, 'Projects', 'NGS_mapping', 'data')
rast_folder <- file.path(basedir, 'raster')
tile_grid_folder <- file.path(rast_folder, 'Reference_tiles')
pal_folder <- file.path(rast_folder, 'PALSAR')
alos_image_folder <- file.path(pal_folder, 'downloads')
tile_prev <- file.path(pal_folder, 'tile_previews')
stackdir <- file.path(rast_folder, 'Stacked')
gdrive_folder <- file.path(rast_folder, 'gdrive')

# File path of the tiles to download images for
tile_path_index <- file.path(basedir, 'vectors', 'test_tiles', 'test_tiles.shp')

# File paths of the command prompt and powershell
CL_path <- "cmd.exe"
PS_path <- "powershell.exe"

# Source the functions
source(file.path(functions_path, 'ALOS_PALSAR_stats_function.R'))
source(file.path(functions_path, 'sentinel_1_stats_function.R'))
source(file.path(functions_path, 'gdal_resample.R'))
source(file.path(functions_path, 'make_folder.R'))

# Account information
# Earthdata login for the Alaska Satellite Foundation website
ASF_username <- "lucyparker11@outlook.com"
ASF_password <- "XXXXXX"

# The name of the google drive to be used with rclone to download via the command line
gdrive_remote <- "gremote:"

# Reading in the tiles to be downloaded
tiles <- st_read(tile_path_index)

# Filtering the tiles to subtiles if required
subtiles <- tiles %>%
  filter(tile_num > 1236)

###### Main Code Processing
###### Step 1
# Download ALOS PALSAR SAR images
cl <- makeCluster(detectCores() - 1)

# Registering the cluster
registerDoParallel(cl)

# Expressions to be evaluated on each core prior to running
clusterEvalQ(cl, {
  library(tidyverse)
  library(sf)
  library(httr)
  # file paths to pass through full script
  storage_drive <- file.path('D:')
  project_path <- file.path(storage_drive, 'Projects', 'NGS_Amazon_mapping')

  scripts_path <- file.path(storage_drive, 'Projects', 'NGS_Amazon_mapping', 'code')
  functions_path <- file.path(storage_drive, 'Projects', 'NGS_Amazon_mapping', 'code', 'functions')
  basedir <- file.path(storage_drive, 'Projects', 'NGS_Amazon_mapping', 'data')
  rast_folder <- file.path(basedir, 'raster')
  pal_folder <- file.path(rast_folder, 'PALSAR')
  alos_image_folder <- file.path(pal_folder, 'downloads')
  tile_prev <- file.path(pal_folder, 'tile_previews')

  tile_path_index <- file.path(basedir, 'vectors', 'purus', 'purus_tile.shp')

  # functions
  source(file.path(functions_path, 'ALOS_PALSAR_stats_function.R'))
  source(file.path(functions_path, 'make_folder.R'))
  tiles <- st_read(tile_path_index)
  subtiles <- tiles

  # objects
  ASF_username <- "lucyparker11@outlook.com"
  ASF_password <- "XXXXX"
})

# Download the images on multiple cores per tile
foreach(i = 1:nrow(tiles)) %dopar%
  {
    source(file.path(scripts_path, 'data_download', 'R', '00_download_ALOS_PALSAR_images.R'))

  }

stopCluster(cl)

###### Step 2
# Running the Google Earth Engine downloads in parallel
# Creating a cluster (3 cores as there are 3 scripts in parallel)
cl2 <- makeCluster(3)

# Registering the cluster
registerDoParallel(cl2)

# Creating the parallel task list
geetasks <- list(file.path(scripts_path, 'data_download', 'R', '01_download_sentinel_1_images.R'), file.path(scripts_path, 'data_download', 'R', '02_download_sentinel_2_images.R'), file.path(scripts_path, 'data_download', 'R', '03_download_ALOS_DSM_images.R'))

# Initialzing Google Earth Engine, reading on tiles and sourcing the statistics function on each core
clusterEvalQ(cl, {
  library(sf)
  rgee::ee_Initialize(drive = TRUE)
  tiles <- st_read(file.path('D:', 'Projects', 'NGS_Amazon_mapping', 'data', 'vectors', 'macapa', 'macapa_tiles.shp'))
  subtiles <- tiles
  source(file.path('D:', 'Projects', 'NGS_Amazon_mapping', 'code', 'functions', 'sentinel_1_stats_function.R'))

})

# Running the three tasks in parallel
foreach(i = 1:length(geetasks), .export = c("subtiles"), .packages = c("rgee")) %dopar% {

  source(geetasks[[i]])

}

stopCluster(cl2)

###### Step 3
# Download rgee data (might try parallelize this once its running individually)
# Creating a cluster (5 cores as there are 5 commands in parallel)
cl3 <- makeCluster(5)

# Registering the cluster
registerDoParallel(cl3)

# rclone from gdrive
rclonetasks <- list(list(command = CL_path, input = paste0('rclone copy ', gdrive_remote, 'VV ', file.path(gdrive_folder, 'VV'))), list(command = CL_path, input = paste0('rclone copy ', gdrive_remote, 'VH ', file.path(gdrive_folder, 'VH'))), list(command = CL_path, input = paste0('rclone copy ', gdrive_remote, 'Optical_Wet ', file.path(gdrive_folder, 'Optical_Wet'))), list(command = CL_path, input = paste0('rclone copy ', gdrive_remote, 'Optical_Dry ', file.path(gdrive_folder, 'Optical_Dry'))), list(command = CL_path, input = paste0('rclone copy ', gdrive_remote, 'Optical_ALOS_DSM_G30m ', file.path(gdrive_folder, 'Optical_ALOS_DSM_G30m'))))

#
foreach(j = 1:length(rclonetasks)) %dopar% {

  system(command = rclonetasks[[j]]$command, input = rclonetasks[[j]]$input)

}

stopCluster(cl3)

###### Step 4
setwd(project_path)

# Calculating ALOS PALSAR statistics
source(file.path(scripts_path, 'tile_preparation', 'R', '04_PALSAR_proctiles.R'))

###### Step 5
# Stack all layers for each tile (ALOS PALSAR, Sentinel 1, Sentinel 2, ALOS DSM)
source(file.path(scripts_path, 'tile_preparation', 'R', '05_stack_layers.R'))

###### Step 6
# Interpolate missing values on each layer
source(file.path(scripts_path, 'tile_preparation', 'R', '06_interpolate_NAs.R'))

