## #######################################################################################
##
## Prepare spatial data for walkability analysis and visualization
##
## Created by Nathaniel Henry, nat@henryspatialanalysis.com
## Purpose: Download and prepare inputs required for walking time analysis
##
## Before running (see README.md for details):
##  - Download R version 4.1 or newer
##  - Install R packages: argparse, elevatr, glue, sf, terra, tidycensus, tigris, units, yaml
##  - Install osmosis command line tool
##  - Update settings in config.yaml to match your desired city
##
## What happens in this script:
##  1. Download census blocks and population for the study area
##  2. Download OSM data and crop to the study area
##  3. Download elevation raster (DEM) for the study area
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
load_packages <- c(
  'argparse', 'elevatr', 'glue', 'sf', 'terra', 'tidycensus', 'tigris', 'units', 'yaml'
)
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

# Create all folders
for(dir in config$directories) dir.create(dir, recursive = TRUE)

# Cache census shapefiles for faster re-runs
options(tigris_use_cache = TRUE)


## 1. Download census blocks and population for the study area -------------------------->

# Set the coordinate reference system that will be used for all spatial data
working_crs <- sf::st_crs(x = settings$working_crs)
# Simple function to return the polygons to unprojected lat-long
to_latlong <- function(obj) sf::st_transform(obj, crs = sf::st_crs(4326))

# Check that there is a unique match for the state + county name
fips_table <- tigris::fips_codes
which_county <- which(
  (fips_table$state_name == settings$state_name) &
  (fips_table$county == settings$county_name)
)
if(length(which_county) == 0) stop(
  "No match for state == '", settings$state_name, "' and county == '", 
  settings$county_name, "'."
)
state_fips <- fips_table[which_county, 'state_code']
county_fips <- fips_table[which_county, 'county_code']

# Download census blocks in the county of interest
blocks_sf <- tidycensus::get_decennial(
  geography = 'block',
  variables = "P1_001N", # Total population
  year = settings$census_year,
  state = state_fips,
  county = county_fips,
  geometry = TRUE,
  cache_table = TRUE
) |> sf::st_transform(crs = working_crs)
names(blocks_sf)[names(blocks_sf) == 'value'] <- 'population'

# Optionally subset to a particular city
if(settings$subset_to_city){
  state_places_sf <- tigris::places(
    state = state_fips,
    cb = FALSE,
    year = settings$census_year
  )
  which_place <- which(settings$city_name == state_places_sf$NAME)
  if(length(which_place) == 0){
    stop("No city in ", settings$state_name, " matching '", settings$city_name, "'.")
  }
  city_sf <- state_places_sf[which_place, ] |> sf::st_transform(crs = working_crs)
  blocks_sf <- sf::st_intersection(x = blocks_sf, y = city_sf)
}

# Optionally remove water bodies
if(settings$remove_water_bodies) blocks_sf <- tigris::erase_water(
  input_sf = blocks_sf,
  area_threshold = settings$water_body_area_threshold
)

# Drop blocks with small areas
blocks_sf$block_area <- sf::st_area(blocks_sf$geometry)
small_blocks <- which(units::drop_units(blocks_sf$block_area) <= settings$min_block_size)
if(length(small_blocks) > 0){
  message("Dropping ", length(small_blocks), " blocks smaller than the area cutoff.")
  blocks_sf <- blocks_sf[-small_blocks, ]
}

# Optionally drop unpopulated blocks
if(settings$subset_to_populated_blocks) blocks_sf <- blocks_sf[blocks_sf$population > 0, ]

# Repair geometry, if needed
if(any(!sf::st_is_valid(blocks_sf))) blocks_sf <- sf::st_make_valid(blocks_sf)

# Make simplified version
blocks_sf_simple <- sf::st_simplify(
  blocks_sf,
  preserveTopology = TRUE,
  dTolerance = settings$simplify_tolerance
)

# Save to file
sf::st_write(
  obj = blocks_sf[, c('GEOID', 'population')] |> to_latlong(),
  dsn = file.path(config$directories$prepared_data, "prepared_blocks.shp"),
  append = FALSE
)
sf::st_write(
  obj = blocks_sf_simple[, c('GEOID', 'population')] |> to_latlong(),
  dsn = file.path(config$directories$prepared_data, "prepared_blocks_simplified.shp"),
  append = FALSE
)
# Plot simplified block outlines 
pdf(
  file.path(config$directories$prepared_data, "simplified_blocks.pdf"),
  height = 10,
  width = 10
)
plot(blocks_sf_simple$geometry |> to_latlong(), lwd = 0.2)
dev.off()

message(
  "Finished processing input blocks. After processing, ", nrow(blocks_sf),
  " blocks remain."
)


## 2. Download OSM data and crop to the study area -------------------------------------->

# Get buffered bounding box of the study area
bb_sf <- blocks_sf |>
  sf::st_bbox() |>
  sf::st_as_sfc() |>
  sf::st_buffer(dist = settings$buffer, endCapStyle = "SQUARE") |>
  sf::st_as_sf() |>
  to_latlong()
bb <- bb_sf |>
  sf::st_bbox()
yaml::write_yaml(
  as.list(bb),
  file = file.path(config$directories$prepared_data, 'extended_bbox.yaml')
)

# Download OSM data for the full state and save it in the raw data folder
full_osm_path <- file.path(config$directories$raw_data, 'osm_extract_full.pbf') |>
  normalizePath() |>
  suppressWarnings()
message("Downloading state-wide OSM extract")
utils::download.file(
  url = config$download_paths$osm_extract,
  destfile = full_osm_path,
  method = 'auto'
)

# Use the osmosis command line tool to crop the full extract file to the bounding box
subset_osm_path <- file.path(config$directories$prepared_data, 'osm_subset.pbf') |>
  normalizePath() |>
  suppressWarnings()
osmosis_command <- glue::glue(c(
  "osmosis --read-pbf {full_osm_path} --bounding-box top='{bb$ymax}' left='{bb$xmin}' ",
  "bottom='{bb$ymin}' right='{bb$xmax}' --write-pbf {subset_osm_path}"
))
message("Running osmosis to subset the OSM file to the study area")
system(osmosis_command)
message("Finished downloading and subsetting OSM extract.")


## 3. Download elevation raster for the study area -------------------------------------->

message("Loading DEM from OpenTopography")
elev_raster_args <- c(list(locations = bb_sf), config$elevation_raster_settings)
elev_raster <- do.call(elevatr::get_elev_raster, args = elev_raster_args)
terra::writeRaster(
  x = elev_raster,
  filename = file.path(config$directories$prepared_data, 'dem.tif')
)

message("Plotting raster DEM for vetting")
er_df <- as.data.frame(elev_raster, xy = T)
colnames(er_df)[3] <- 'Elevation'
fig <- ggplot() + 
  geom_raster(data = er_df, aes(x=x, y=y, fill = Elevation)) + 
  geom_sf(data = blocks_sf_simple |> to_latlong(), fill = NA, linewidth = .2, alpha = .5) +
  scale_fill_gradientn(colours = viridisLite::viridis(10)) +
  theme_void()
pdf(file.path(config$directories$prepared_data, 'plot_raster_dem.pdf'), height = 10, width = 10)
print(fig)
dev.off()

message(
  "Finished with data preparation. Prepared data saved to ",
  config$directories$prepared_data
)
