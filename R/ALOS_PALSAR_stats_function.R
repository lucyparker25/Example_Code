#' Function to calculate temporal stats of PALSAR images
#' Lucy Parker
#'
#' @param rbrick_hh A RasterBrick (or RasterStack) object containing all temporal images from the HH polarisation for a single tile
#' @param rbrick_hv A RasterBrick (or RasterStack) object containing all temporal images from the HV polarisation for a single tile
#' @param tilename The name of the tile which the composite is of
#' @param filepath The file path where the raster should be saved. *Do not include ".tif" in this name*
#' @param szn The season of the time range (i.e. wet or dry)
#'
#' @return Each statistical layer will be written to a raster under the name saved in the previous step in the script
#' @export

# Writing the function
temp_PALSAR_stats <- function(rbrick_hh1, rbrick_hv1, tilename, filepath) {

  tryCatch({
    ### Calculating all the stats in individual layers
    # Removing the extreme values

    # Calculating the proportional values for each aligned image

    print("Calculating quantiles hh")
    # HH
    align_quants_hh <- raster::quantile(rbrick_hh1, probs = c(0.0005, 0.9995))

    # Calculating the mean vals
    mean_vals_hh <- as.data.frame(align_quants_hh) %>%
      dplyr::summarise(across(c("0.05%", "99.95%"), ~ mean(.x, na.rm = TRUE)))

    print("Reclassifying extreme vals as NA hh")
    # Reclassifying the low tail
    hh_int <- raster::reclassify(rbrick_hh1, cbind(-Inf, mean_vals_hh$`0.05%`, NA), right=FALSE)

    # Reclassifying the high tail
    hh_int2 <- raster::reclassify(hh_int, cbind(mean_vals_hh$`99.95%`, Inf, NA), right=FALSE)

    # Reclassifying extact 0's as NA as this is an error
    rbrick_hh <- raster::reclassify(hh_int2, cbind(-0.000001, 0.000001, NA), right=FALSE)

    print("Calculating quantiles hv")
    # HV
    align_quants_hv <- raster::quantile(rbrick_hv1, probs = c(0.0005, 0.9995))

    # Calculating the mean vals
    mean_vals_hv <- as.data.frame(align_quants_hv) %>%
      dplyr::summarise(across(c("0.05%", "99.95%"), ~ mean(.x, na.rm = TRUE)))

    print("Reclassifying extreme vals as NA hv")

    # Reclassifying the low tail
    hv_int <- raster::reclassify(rbrick_hv1, cbind(-Inf, mean_vals_hv$`0.05%`, NA), right=FALSE)

    # Reclassifying the high tail
    hv_int2 <- raster::reclassify(hv_int, cbind(mean_vals_hv$`99.95%`, Inf, NA), right=FALSE)

    rbrick_hv <- raster::reclassify(hv_int2, cbind(-0.000001, 0.000001, NA), right=FALSE)

    # Calculating the statistical layers
    ### HH
    # Calculating TMB
    print("Calculating HH median")
    hh_median <- calc(rbrick_hh, fun = median, na.rm = T)

    # Calculating TSD
    print("Calculating HH standard deviation")
    hh_std <- calc(rbrick_hh, fun = sd, na.rm = T)

    # Calculating MiB, MaB
    print("Calculating HH min, max")
    hh_min <- calc(rbrick_hh, fun = min, na.rm = T)

    hh_max <- calc(rbrick_hh, fun = max, na.rm = T)

    ### HV
    # Calculating TMB
    print("Calculating HV median")
    hv_median <- calc(rbrick_hv, fun = median, na.rm = T)

    # Calculating TSD
    print("Calculating HV standard deviation")
    hv_std <- calc(rbrick_hv, fun = sd, na.rm = T)

    # Calculating MiB, MaB
    print("Calculating HV min, max")
    hv_min <- calc(rbrick_hv, fun = min, na.rm = T)

    hv_max <- calc(rbrick_hv, fun = max, na.rm = T)

    ## HH/HV ratio
    # calculating HH/HV ratio
    print("Calculating HH/HV ratio using means")
    hhhv <- overlay(hh_median, hv_median, fun = function(r1, r2) {return(r1 - r2)})

    ### Stacking the stats layers into one file (both pols)
    print("Stacking layers together")
    layer_stack <- raster::stack(hh_median, hh_std, hh_min, hh_max, hv_median, hv_std, hv_min, hv_max, hhhv)

    # Writing a raster in and storing in the specified file path
    print("writing raster to comp folder")
    raster::writeRaster(layer_stack, paste0(filepath, "\\", tilename, "_composite"), format = "GTiff")

  },

  error = function(e) {

  },

  finally = {
    message("Stats completed, stacked and stored!")

  })

}
