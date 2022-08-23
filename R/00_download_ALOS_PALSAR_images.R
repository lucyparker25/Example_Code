# NGS Mapping
# Downloading PALSAR images from the Alaska Satellite Facility
# Lucy Parker
# 11-03-2022

# Loading necessary packages
#library(tidyverse)
#library(sf)
#library(httr)

############## PROCESSING STEPS START HERE ################
print(paste0('#### Setting downloads folder to ', alos_image_folder))

# Create downloads folder
foldermake(rast_folder)
foldermake(pal_folder)
foldermake(alos_image_folder)

############## PROCESSING STEPS START HERE ################
# Create a counter
tilecount <- 1

# Number of tiles
tiletot <- nrow(subtiles)

##### Looping over tiles
for (i in 1:nrow(subtiles)) {

  # Create tile folder structure
  tile_name <- paste0('tile_', subtiles[i, ]$tile_num)

  print(paste0('########### Processing tile ', subtiles[i, ]$tile_num, ' (', tilecount, '/',
               tiletot, ')'))

  ######################### DOWNLOAD USING WGET ################################

  print(paste0('########### Part 1 - Downloading images for tile_', subtiles[i, ]$tile_num))

  print('#### Querying ASF')

  ### Query data availability
  # Get bounding box for the selected tile as a comma separated string
  # Storing the individual coords
  xmin <- subtiles[i, ]$xmin
  ymin <- subtiles[i, ]$ymin
  xmax <- subtiles[i, ]$xmax
  ymax <- subtiles[i, ]$ymax

  # Combining into the bbox
  bbox <- paste(xmin, ymin, xmax, ymax, sep = ',')

  # Query the ASF API for PALSAR1 availability for the selected tile, using the parameters above
  req <-  GET('https://api.daac.asf.alaska.edu/services/search/param',
              authenticate('lucyparker11@outlook.com', 'Casper25!'),
              timeout(1000),
              query = list('bbox'= bbox,
                           'platform'='ALOS',
                           'processingLevel'='L1.5',
                           'beamMode'='FBD,FBS',
                           'flightDirection'='ASC',
                           'output'='csv'))

  # Checking the request status
  print(http_status(req)$message)

  # Extract response from resulting query as data frame, keeping only URL, beam mode and file size
  imgquery <- suppressMessages(as.data.frame(content(req)))

  # Changing the column name in base as it wasn't working with dplyr
  colnames(imgquery)[colnames(imgquery) == 'Beam Mode'] <- 'Beam_Mode'
  colnames(imgquery)[colnames(imgquery) == 'Size (MB)'] <- 'Size_MB'

  # Selcting the URL, Beam Mode and Size (MB)
  imgquery <- imgquery %>%
    dplyr::select(URL,
                  Beam_Mode,
                  Size_MB)

  ### Compute and display query summary

  # Per Beam Mode
  beamsummary <- imgquery %>%
    dplyr::group_by(Beam_Mode) %>%
    dplyr::summarise(Beam_Mode = unique(Beam_Mode),
                     Img_Number = n(),
                     Size_MB = sum(Size_MB))

  # Total summary
  totsummary <- imgquery %>%
    dplyr::summarise(N_images = n(),
                     Size_MB = sum(Size_MB))

  print(beamsummary)

  # Save image list to csv, putting the number of images on the file name for easy checking
  csvname <- file.path(alos_image_folder,
                       paste(tile_name,
                             (beamsummary[1, 1]),
                             (beamsummary[1, 2]),
                             (beamsummary[2, 1]),
                             (beamsummary[2, 2]),
                             'total',
                             nrow(imgquery),
                             'available_imgs.csv',
                             sep = '_'
                       )
  )

  write_excel_csv(imgquery, paste(csvname)) # Should automatically encode UTF-8

  ### Downloading!

  print(paste('#### Starting download of ',
              paste(tile_name),
              ', with ',
              paste(totsummary[1,1]),
              ' images, totaling ',
              paste((round(totsummary[1, 2], 1))),
              ' Mb'))

  # Saving each image URL in a list
  imglist <-  as.list(imgquery$URL)

  ################### TESTING #########################
  # Setting the directory
  setwd(alos_image_folder)

  # Creating counter
  ct <- 1

  ### Downloading each image
  # Loop running through each image
  for (j in (1:length(imglist))) {

    print(paste('Downloading image ',
                paste(ct),
                ' of ',
                paste(totsummary[1, 1]),
                ' for ',
                paste(tile_name)))

    # Storing start time
    start <- Sys.time()

    # Downloading each image using the system command line
    system2(args = paste(
      'wget',
      paste0('--http-user=', ASF_username),
      paste0('--http-password=', ASF_password),
      '--no-check-certificate',
      '--show-progress',
      '--no-clobber',
      '--retry-connrefused',
      '--waitretry=1',
      '-t 0',
      '--secure-protocol=TLSv1',
      imglist[[j]])
    )

    # Adding one to the counter
    ct <- ct + 1

  }

  # Adding one to the counter
  tilecount <- tilecount + 1

  print(paste0('########### Finished downloading tile ', paste(tile_name)))
  print(paste("Elapsed time:", Sys.time() - start))
  print('###########################################')

}

