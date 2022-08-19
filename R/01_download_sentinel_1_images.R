# Downloading Sentinel 1 images from the Google Earth Engine
# Lucy Parker

# Source this script from either main_script.R or main_script_parallel.R to run
# Must have a linked and loaded Google account to use with enough storage to save the files before copied to the local drive

############### Processing steps start here ################

# Creating the specific variables for this analysis
# Creating a df containing the data to download
collections <- data.frame(Layer = c("S1_VV", "S1_VH"),
                          Image_Collection = c("COPERNICUS/S1_GRD", "COPERNICUS/S1_GRD"),
                          Polarisation = c("VV", "VH"),
                          Instrument_Mode = c("IW", "IW"),
                          Resolution = c("H", "H"))

# Creating a counter
layercount <- 1

# Total number of layers
layertot <- nrow(collections)

# Number of tiles
tiletot <- nrow(subtiles)

########## Downloading data########
# Downloading images from GEE for each layer and creating statistical composites of each tile per layer

# Looping through each layer in collections
for (i in 1:nrow(collections)) {

  print(paste0("########### Processing layer ",
               collections[i, ]$Layer,
               "_",
               "(",
               layercount,
               "/",
               layertot,
               ")"))

  # Specifying which collection to use
  img_coll <- ee$ImageCollection(collections[i, ]$Image_Collection)$
    filter(ee$Filter$listContains("transmitterReceiverPolarisation", collections[i, ]$Polarisation))$
    filter(ee$Filter$eq("instrumentMode", collections[i, ]$Instrument_Mode))$
    filter(ee$Filter$eq("resolution", collections[i, ]$Resolution))$
    select(collections[i, ]$Polarisation)

  # Create an empty task list
  tasks <- list()

  # Creating a counter
  tilecount <- 1

  # Looping through each tile
  for (j in 1:nrow(subtiles)) {

    print(paste0("########### Processing tile ",
                 subtiles[j, ]$tile_num,
                 "_",
                 "(",
                 tilecount,
                 "/",
                 tiletot,
                 ")"))

    # Specifying only the jth tile
    ee_img <- subtiles[j,]

    # Making each tile slightly larger
    ee_img$geometry[[1]] <- ee_img$geometry[[1]] + 150

    # Changing from a sf object to a ee object
    ee_img <- sf_as_ee(ee_img)

    # Creating a geometry variable to clip by
    ee_geom <- ee_img$geometry()

    # Filtering each layer by tile
    img_tile <- img_coll$
      filterBounds(ee_img)

    # Calculating the statistics for each tile
    tile_stats <- tilestats(img_tile, paste("tile_", subtiles[j, ]$tile_num, sep = ""))

    # Export file to google drive
    # Specifying export parameters
    tasks[[j]] <- ee_image_to_drive(image = tile_stats$toFloat(),
                                    region = ee_geom,
                                    scale = 10,
                                    maxPixels = 2555756344,
                                    fileFormat = "GeoTIFF",
                                    fileNamePrefix = paste0("tile_",
                                                            subtiles[j, ]$tile_num,
                                                            "_",
                                                            collections[i, ]$Polarisation),
                                    timePrefix = FALSE,
                                    folder = paste0(collections[i, ]$Polarisation))

    start <- Sys.time()
    # Starting the export
    tasks[[j]]$start()

    # Monitoring
    ee_monitoring(eeTaskList = TRUE,
                  max_attempts = Inf)

    print(paste("Downloading composite image ##",
                paste0(subtiles[j, ]$tile_num, "_composite ##"),
                tilecount,
                "of",
                paste(tiletot),
                "for layer",
                collections[j, ]$Layer))

    # Adding one to the tile count
    tilecount <- tilecount + 1

    print(paste("########### Finished downloading tile ", paste(subtiles[j, ]$tile_num, "_", collections[j, ]$Layer, "_composite #############")))

  }

  # Adding one ot the layer count
  layercount <- layercount + 1

  print(paste0("########### Finished processing layer ", collections[i, ]$Layer, ' Elapsed time:', Sys.time() - start))

}
