## #######################################################################################
##
## Download points of interest (POIs) from OpenStreetMap
##
## Created by Nathaniel Henry, nat@henryspatialanalysis.com
## Purpose: Download destinations from OpenStreetMap based on place keywords
##
## Before running (see README.md for details):
##  - Download R version 4.1 or newer
##  - Install R packages: argparse, data.table, httr, glue, yaml
##  - Run 1_prepare_blocks.R to define a bounding box for your city ("extended_bbox.yaml",
##    saved in the prepared data folder).
##  - Optional: Update the `osm_destination_queries` arguments config.yaml to define 
##    destination types and their associated OpenStreetMap tags. For more information,
##    see the README.
##
## What happens in this script:
##  1. Create a function to download download POIs from OpenStreetMap
##  2. Download POIs based on the config, format as a single table, and save
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
load_packages <- c('argparse', 'data.table', 'httr', 'glue', 'yaml')
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
for(dir in config$directories) dir.create(dir, recursive = TRUE, showWarnings = FALSE)


## 1. Create a function to download download POIs from OpenStreetMap -------------------->

API_ENDPOINT <- config$download_paths$overpass_api_endpoint

# Load bounding box saved in 1_prepare_blocks.R and convert to string
bb <- yaml::read_yaml(
  file.path(config$directories$prepared_data, 'extended_bbox.yaml')
)
BBOX_TEXT <- glue::glue("[bbox:{bb$ymin},{bb$xmin},{bb$ymax},{bb$xmax}];")

# Helper function to query Overpass for nodes, ways, and relations matching a tag or set
#  of tags and return JSON results
query_overpass <- function(tags){
  # Build the query
  format_tags <- function(tag) glue::glue("node[{tag}]; way[{tag}]; relation[{tag}];")
  tag_text <- lapply(tags, format_tags) |> unlist() |> paste(collapse = ' ')
  address_tags <- c('housenumber', 'street', 'city', 'postcode')
  address_text <- paste0('"addr:', address_tags, '"') |> paste(collapse = ', ')
  full_query_text <- glue::glue(
    '[out:csv(::lat, ::lon, name, {address_text}; true; ",")]',
    '{BBOX_TEXT}({tag_text}); out center;'
  )
  # Submit the query to the Overpass API
  query_results <- httr::POST(API_ENDPOINT, body=full_query_text)
  # If the query fails, send an informative error
  httr::stop_for_status(query_results)
  # Otherwise, return the query JSON
  return(httr::content(query_results, as = 'text', encoding = 'UTF-8'))
}


##  2. Download POIs based on the config, format as a single table, and save ------------>

destination_types <- names(config$osm_destination_queries)

destinations_table <- lapply(destination_types, function(d_type){
  message("Querying the OpenStreetMap Overpass API for ", d_type, "...")
  # Pull the Overpass API results, filtering on the tags for this destination type
  osm_tags <- config$osm_destination_queries[[d_type]]
  overpass_results <- query_overpass(osm_tags) |>
    textConnection() |>
    read.csv(sep = ',') |>
    data.table::as.data.table() |>
    na.omit(cols = c('X.lat', 'X.lon'))
  # Keep only the key fields: name, latitude, longitude, address, destination type
  formatted_locations <- (overpass_results
    [, address := paste(addr.housenumber, addr.street, addr.city, addr.postcode)]
    [, address := gsub(' +', ' ', address)]
    [address == ' ', address := NA_character_ ]
    [, .(name, lon = X.lon, lat = X.lat, address, type = d_type)]
  )
  return(formatted_locations)
}) |> rbindlist()

# Summarize results
message("Summary of results:")
knitr::kable(destinations_table[, .(Count = .N), by = .(`Destination type` = type)])

# Save table
data.table::fwrite(
  destinations_table,
  file = file.path(config$directories$prepared_data, 'destinations_osm.csv')
)
