# Interpolating any missing values in the raster
# Lucy Parker

# Source this script from either main_script.R or main_script_parallel.R to run

############### Processing steps start here ################

# Filtering the stacked images ONLY for the tiles in the tile_path_index
for(l in 1:nrow(subtiles)) {

  # Storing the filepaths of the requested stacked images
  temp_stack <- as.data.frame(file.path(stackdir, paste0('tile_', subtiles$tile_num[l], '_stack.tif')))
  colnames(temp_stack) <- "filepath"

  # Storing file paths in a data frame
  if(l == 1) {

    sub_stack <- temp_stack

  } else {

    sub_stack <- dplyr::bind_rows(sub_stack, temp_stack)

  }

}

# Run through every tile within the sub_stack
for (j in 1:nrow(sub_stack)){

  print("Reading in raster")
  # Read in the raster stack
  tile_rast <- rast(sub_stack[j, ])

  # Loop through each band in the stack
  for (i in 1:length(tile_rast@ptr$depth)) {

    # Storing a single band
    tile_rast_up <- tile_rast[[i]]

    # While there are still NAs present, interpolate
    while (freq(tile_rast_up, value = NA)[,3] > 0) {

      print(paste("interpolating NAs for layer", i, sep = " "))

      # Replacing the NAs with the mean of the 3x3 matrix surrounding the cell/ pixel
      tile_rast_up <- terra::focal(tile_rast_up, w = matrix(1,3,3), fun = mean, na.policy = "only", na.rm = TRUE)

      # Print how many NAs are remaining
      print(freq(tile_rast_up, value = NA)[,3])

    }

    print(paste0("No more NAs in layer ", i))
    print(paste0("Adding layer ", i, " to stack"))

    # Re-stacking into a new raster
    if (i == 1) {

      tile_up <- tile_rast_up

    } else {

      add(tile_up) <- tile_rast_up

    }

  }

  # Renaming the layers of the raster
  # Naming the layers
  names(tile_up) <- c('S1_TSD_VV', 'S1_TMB_VV', 'S1_MiB_VV', 'S1_MaB_VV', 'S1_TSD_VH', 'S1_TMB_VH', 'S1_MiB_VH', 'S1_MaB_VH', 'S1_VVVH_Ratio', 'S2_NDVI_Dry', 'S2_NDWI_Dry', 'S2_NDVI_Wet', 'S2_NDWI_Wet', 'AW3D_Elevation', 'PLSR_TMB_HH', 'PLSR_TSD_HH', 'PLSR_MiB_HH', 'PLSR_MaB_HH', 'PLSR_TMB_HV', 'PLSR_TSD_HV', 'PLSR_MiB_HV', 'PLSR_MaB_HV', 'PLSR_HHHV_Ratio', 'S1_Range_VV', 'S1_Range_VH', 'PLSR_Range_HH', 'PLSR_Range_HV')

  # Writing the raster to file
  terra::writeRaster(tile_up, file.path(final_stack_dir, paste0('tile_', subtiles$tile_num[j], '_stack.tif')), overwrite = TRUE)

}

