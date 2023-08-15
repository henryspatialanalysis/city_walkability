## #######################################################################################
##
## Download points of interest (POIs) from Seattle-specific data sources
##
## Created by Nathaniel Henry, nat@henryspatialanalysis.com
## Purpose: Download destinations from data sources specific to Seattle
##
## Note: this script formats location data for parks, transit stops, and libraries. The
##   sources for these destinations are specific to the city of Seattle and King County,
##   but might provide a template for data preparation in other cities.
##
## Before running (see README.md for details):
##  - Download R version 4.1 or newer
##  - Install R packages: argparse, data.table, glue, sf, yaml
##  - Run 1_prepare_blocks.R to define a bounding box for your city ("extended_bbox.yaml",
##    saved in the prepared data folder).
##
## What happens in this script:
##  1. Download park, transit stop, and library data from the web
##  2. Prepare parks: combine multiple sources of park data and convert to points
##  3. Prepare light rail stops
##  4. Prepare bus stops: subset to active stops
##  5. Prepare libraries
##  6. Combine points of interest prepared in this script into a single table and save
##
## #######################################################################################

## SET DEFAULT CONFIG PATH
#  Set the location of the config.yaml file that determines all settings for this script.
#  This path will only be used if you run this script interactively; if you run this
#  script from the command line, this default will be ignored.
#
#  If config arguments are set correctly, you should not need to edit this script below
#  line 30.
DEFAULT_CONFIG_FILEPATH <- "~/repos/city_walkability/analysis/config.yaml"


## Setup -------------------------------------------------------------------------------->

# Load all required packages
load_packages <- c('argparse', 'data.table', 'glue', 'sf', 'yaml')
load_packages |> lapply(library, character.only = T) |> invisible()

# Load config.yaml
if(interactive()){
  config_filepath <- DEFAULT_CONFIG_FILEPATH
  message("Using default config location: ", config_filepath)
} else {
  parser <- argparse::ArgumentParser()
  parser$add_argument(
    "--config_filepath",
    type = 'character',
    help = "Full path to the config.yaml file containing run settings"
  )
  config_filepath <- parser$parse_args(commandArgs(trailingOnly = TRUE))$config_filepath
}
config <- yaml::read_yaml(config_filepath)
settings <- config$project_settings
dl_paths <- config$download_paths

# Create all output folders
for(dir in config$directories) dir.create(dir, recursive = TRUE, showWarnings = FALSE)

# Load the bounding box for this analysis
bb <- yaml::read_yaml(
  file.path(config$directories$prepared_data, 'extended_bbox.yaml')
)
bb_sf <- sf::st_bbox(unlist(bb))

## 1. Download park, transit stop, and library data from the web ------------------------>

seattle_data_sources <- grep('^seattle_', names(dl_paths), value = T)

# Create a list that will store all raw data objects to be formatted below
raw_data_list <- vector('list', length = length(seattle_data_sources))
names(raw_data_list) <- seattle_data_sources

# Download and then load each file
for(this_source in seattle_data_sources){
  message("Downloading ", this_source)
  source_url <- dl_paths[[this_source]]
  data_type <- ifelse(endsWith(tolower(source_url), 'csv'), 'csv', 'geojson')
  dest_file <- glue::glue("{config$directories$raw_data}/{this_source}.{data_type}")
  # Download file to the raw data folder
  utils::download.file(url = source_url, destfile = dest_file)
  # Load it as either a data.table (if CSV) or sf (if geoJSON) object
  if(data_type == 'csv'){
    raw_data_list[[this_source]] <- data.table::fread(dest_file)
  } else {
    raw_data_list[[this_source]] <- sf::st_read(dest_file)
  }
}


## 2. Prepare parks: combine multiple sources of park data and convert to points -------->

# Combine parks data sources
all_parks <- rbind(
  raw_data_list$seattle_spr_parks['NAME'],
  raw_data_list$seattle_other_parks['NAME']
) |> sf::st_transform(crs = sf::st_crs(settings$working_crs))

# Subset to parks over 20,000 square feet in area
all_parks$area <- sf::st_area(all_parks$geometry)
parks_subset <- all_parks[
  all_parks$area > units::set_units(settings$park_min_size_sqft, ft^2),
]

# Drop some areas that are maintained by SPR or similar agencies but wouldn't be
#  considered parks in the conventional sense
parks_subset <- parks_subset[!grepl(
  'boulevard|centerstrip|hs|moorage|patrol|ramp|shops|walkway',
  parks_subset$NAME, ignore.case = T
), ]

# Parks are defined as multi-polygons, but the routing tool needs destionation points.
#   Convert polygons to candidate destination points using the following method. Split 
#   multi-polygons into individual polygons. Then, for each polygon:
#   - Take the centroid, if it falls in the polygon's boundaries
#   - Sample points from the polygon's perimeter at regular 500-foot intervals (about a 2 
#     minute walk), or 1/4 the polygon's perimeter, whichever is smaller
park_points_list <- lapply(seq_len(nrow(parks_subset)), function(row_idx){
  park_name <- parks_subset$NAME[row_idx]
  park_polygons <- parks_subset$geometry[row_idx] |> sf::st_cast(to='POLYGON')
  park_points <- lapply(seq_along(park_polygons), function(poly_idx){
    poly <- park_polygons[poly_idx]
    # Sample lines along the perimeter
    perimeter <- sf::st_cast(poly, to = 'LINESTRING')
    sample_points <- sf::st_line_sample(
      x = perimeter,
      density = min(units::set_units(500, ft), sf::st_length(perimeter)/4),
      type = 'regular'
    ) |> sf::st_cast(to = 'POINT')
    # Take centroid, if it overlaps the polygon
    poly_centroid <- sf::st_centroid(poly)
    centroid_intersects_poly <- sf::st_intersects(poly_centroid, poly, sparse = F)[1, 1]
    if(centroid_intersects_poly) sample_points <- c(sample_points, poly_centroid)
    return(sample_points)
  }) |> Reduce(f = function(x, y) c(x, y))
  return(sf::st_sf(name = park_name, geometry = park_points))
})

# Combine into a single SF object and convert back to latitude-longitude
all_park_points <- do.call(park_points_list, what = rbind) |>
  sf::st_transform(crs = sf::st_crs(4326))

# Convert to a table with the fields name, lon, lat, type
parks_table <- data.table::data.table(
  name = all_park_points$name,
  lon = sf::st_coordinates(all_park_points)[, 'X'],
  lat = sf::st_coordinates(all_park_points)[, 'Y'],
  type = 'Parks'
)


## 3/4. Prepare bus and light rail stops ------------------------------------------------>

# Metadata for transit stops here:
# https://www5.kingcounty.gov/sdc/Metadata.aspx?Layer=transitstop

# Subset to active, non-school transit stops with at least one assigned route
active_stops <- raw_data_list$seattle_bus_stops[
  (STOP_STATUS == 'ACT') & (STOP_TYPE != 'SCH') & (ROUTE_LIST != ""),
]

# Subset to city extended bounding box
stops_cropped <- sf::st_as_sf(active_stops, coords = c('X', 'Y'), crs = sf::st_crs(4326)) |>
  sf::st_crop(y = bb_sf)
stops_cropped_table <- cbind(
  sf::st_coordinates(stops_cropped),
  as.data.table(stops_cropped)
)

# Split into light rail (routes 599/599N) and all other stops
stops_cropped_table[, type := 'Other transit stops']
stops_cropped_table[grepl('599', ROUTE_LIST), type := 'Light rail stops']

# Format as table with columns name, lon, lat, and type
transit_table <- (stops_cropped_table
  [, .(name = ON_STREET_NAME, lon = X, lat = Y, type)]
  [order(type, name)]
)


## 5. Prepare libraries ----------------------------------------------------------------->

libraries_cropped <- raw_data_list$seattle_libraries[CODE == 390, ] |>
  sf::st_as_sf(coords = c('X', 'Y'), crs = sf::st_crs(4326)) |>
  sf::st_crop(y = bb_sf)

libraries_table <- cbind(
  sf::st_coordinates(libraries_cropped),
  as.data.table(libraries_cropped)
)[, .(name = NAME, address = ADDRESS, lon = X, lat = Y, type = 'Libraries')]


## 6. Combine points of interest prepared in this script into a single table and save --->

destinations_table_city_specific <- rbindlist(
  list(parks_table, transit_table, libraries_table),
  use.names = T,
  fill = T
)
data.table::fwrite(
  destinations_table_city_specific,
  file = file.path(config$directories$prepared_data, 'destinations_city_specific.csv')
)
