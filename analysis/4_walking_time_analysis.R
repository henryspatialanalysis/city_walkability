## #######################################################################################
##
## Run walking accessibility analysis
##
## Created by Nathaniel Henry, nat@henryspatialanalysis.com
## Purpose: Estimate walking time from each block in a city to various destination types
##
## Before running (see README.md for details):
##  - Download R version 4.1 or newer
##  - Install R packages: argparse, data.table, glue, r5r, sf, yaml
##  - Run at least 1_prepare_blocks.R and 2_prepare_pois_from_openstreetmap.R to get R5R
##    inputs, origin (block) locations, and destination (POI) locations from OpenStreetMap
##
## What happens in this script:
##  1. Load analysis inputs (origins, destinations)
##  2. Launch R5
##  3. Estimate walking accessibility from each origin block to each destination type
##  4. Save results as a table (for further analysis) and in JSON format (for visualization)
##
## #######################################################################################

## SET DEFAULT CONFIG PATH
#  Set the location of the config.yaml file that determines all settings for this script.
#  This path will only be used if you run this script interactively; if you run this
#  script from the command line, this default will be ignored.
#
#  If config arguments are set correctly, you should not need to edit this script below
#  line 30.
DEFAULT_CONFIG_FILEPATH <- "/home/nathenry/repos/city_walkability/analysis/config.yaml"


## Setup -------------------------------------------------------------------------------->

# Load all required packages (except for R5R, which is loaded later)
load_packages <- c('argparse', 'data.table', 'glue', 'sf', 'tictoc', 'yaml')
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

# Create all output folders
for(dir in config$directories) dir.create(dir, recursive = TRUE, showWarnings = FALSE)


##  1. Load analysis inputs (origins, destinations) ------------------------------------->

## Load blocks and get centroids (origins)
prepared_blocks <- sf::st_read(file.path(
  config$directories$prepared_data, 'prepared_blocks.shp'
))
origin_centroids <- prepared_blocks |>
  sf::st_make_valid() |>
  sf::st_centroid(of_largest_polygon = T) |>
  sf::st_coordinates() |>
  as.data.table()
origins <- cbind(
  as.data.table(prepared_blocks)[, .(GEOID, population)],
  origin_centroids[, .(lon = X, lat = Y)]
)
origins[, id := as.character(.I) ]

# Load destinations pulled from OSM
destinations <- data.table::fread(
  file.path(config$directories$prepared_data, 'destinations_osm.csv')
)
# If destinations from city-specific sources (i.e. the output of script #3) are available,
#   add them to the table of destinations
city_specific_file <- file.path(
  config$directories$prepared_data, 'destinations_city_specific.csv'
)
if(file.exists(city_specific_file)){
  city_specific_destinations <- data.table::fread(city_specific_file)
  destinations <- data.table::rbindlist(
    list(destinations, city_specific_destinations),
    use.names = T,
    fill = T
  )
}
destinations[, id := as.character(.I) ]
opportunity_types <- unique(destinations$type)

## Load visualization blocks - analysis results will be merged on later
prepared_blocks_simplified <- sf::st_read(file.path(
  config$directories$prepared_data, 'prepared_blocks_simplified.shp'
))


## 2. Launch R5 ------------------------------------------------------------------------->

# Set Java allowed memory before loading R5R
options(java.parameters = paste0("-Xmx", settings$r5_mem_gb, "G"))
library(r5r)
# Set up R5 for the study area - this may take several minutes for the first setup
# If this function yields an error, try launching R with admin permissions
r5r_core <- r5r::setup_r5(data_path = config$directories$prepared_data)


## 3. Estimate walking accessibility from each origin block to each destination type ---->

travel_times_list <- vector('list', length = length(opportunity_types))
names(travel_times_list) <- opportunity_types

tictoc::tic("Calculating all travel times")
for(o_type in opportunity_types){
  travel_times_by_od_pair <- r5r::travel_time_matrix(
    r5r_core = r5r_core,
    origins = origins,
    destinations = destinations[type == o_type, ],
    mode = "WALK",
    max_trip_duration = 30L
  )
  travel_times_list[[o_type]] <- travel_times_by_od_pair[
    , .(travel_time = min(travel_time_p50, na.rm=T)),
    by = .(id = from_id)
  ][, type := o_type ]
}
tictoc::toc()

## Summarize results, including missing results
travel_times_table <- data.table::rbindlist(travel_times_list)
travel_times_long <- (
  data.table::CJ(id = origins$id, type = opportunity_types, travel_time = NA_real_ )
  [origins, GEOID := i.GEOID, on = 'id']
  [travel_times_table, travel_time := i.travel_time, on = c('id', 'type')]
  [order(type, as.numeric(id))]
)

## Create a version that is reshaped wide with NAs filled for visualization purposes
travel_times_wide <- data.table::copy(travel_times_long)[, .(
  GEOID,
  type = tolower(gsub(' ', '_', type)),
  travel_time = nafill(travel_time, fill = 999L)
)] |> data.table::dcast.data.table(GEOID ~ type, value.var = 'travel_time')


## 4. Save results as a table and in JSON format ---------------------------------------->

# Long results table saved directly
data.table::fwrite(
  travel_times_long,
  file = file.path(config$directories$results, 'travel_time_results.csv')
)

# Merge wide results table onto the visualization polygons
results_viz_sf <- merge(
  x = prepared_blocks_simplified,
  y = travel_times_wide,
  by = 'GEOID',
  all = TRUE
)
# Save as a GEOJSON file
geojson_fp <- file.path(config$directories$results, 'travel_time_results_for_viz.geojson')
sf::st_write(results_viz_sf, dsn = geojson_fp)


## 5. Create the JS file that defines map boundaries and polygons ----------------------->

js_fp <- gsub(pattern = '.geojson$', replacement = '.js', x = geojson_fp)

## Get the bounding and starting coordinates/zoom for the map
bb <- yaml::read_yaml(file.path(config$directories$prepared_data, 'extended_bbox.yaml'))
bb$xmid <- mean(bb$xmin, bb$xmax)
bb$ymid <- mean(bb$ymin, bb$ymax)
bb$zoom <- settings$viz_starting_zoom_level

# Convert to a JSON object
bb_text <- glue::glue("var bounding_box = {jsonlite::toJSON(bb, auto_unbox = T)};")

# Read and edit the GeoJSON text
geojson_text <- readLines(geojson_fp)
geojson_text[1] <- paste0("var travel_time = ", geojson_text[1])
geojson_text[length(geojson_text)] <- paste0(geojson_text[length(geojson_text)], ";")

# Save the full JS file with both variable definitions and comments
full_text <- c(
  "// Define map boundaries",
  bb_text,
  "// Define travel times by block",
  geojson_text
)
writeLines(text = full_text, con = js_fp)
