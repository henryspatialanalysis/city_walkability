# 15-minute city analysis code

The scripts in this folder calculate travel times from blocks to various amenities across a city or county.


## Setup

Before running the scripts in this folder, make sure that you have the following installed on your computer:
- Install [R](https://cran.r-project.org/bin/windows/base/) version 4.1 or above. New R users might find [RStudio](https://posit.co/download/rstudio-desktop/) a useful way to navigate the code.
- Install 12 R packages from CRAN: `install.packages(c('argparse', 'data.table', 'devtools', 'httr', 'glue', 'sf', 'terra', 'tictoc', 'tidycensus', 'tigris', 'units', 'yaml'))`
- Install the "elevatr" package from GitHub: `devtools::install_github('jhollist/elevatr')`
- Install the free Java SE Development Kit 11, a requirement for the "r5r" package. For more information, see section 2 from this "r5r" [vignette](https://cran.r-project.org/web/packages/r5r/vignettes/r5r.html).
- Install the "r5r" package from GitHub: `devtools::install_github("ipeaGIT/r5r", subdir = "r-package")`

You may also want to apply for API keys to repeatedly pull US Census and OpenTopography data.
- Apply for a US Census API key [here](https://api.census.gov/data/key_signup.html)
- Apply for an OpenTopography API key by creating an account on [their website](https://opentopography.org/), then selecting "Request an API Key"
- Add both API keys to the `~/.Renviron` file (you may need to create this file if it does not already exist). The file should include lines that look like this:

```
OPENTOPO_KEY="asdf1234" # Update to the actual key
CENSUS_API_KEY="ghjk5678" # Update to the actual key
```


## Configuration file

Scripts in this folder all run based on settings in the `config.yaml` file. See the comments in the file for more details about each setting.

If you are reproducing this analysis for Seattle, you only need to change the `directories` in `config.yaml` to change where the outputs get saved.

If you are running this analysis for another city or county in the United States, you will also need to change `state_name`, `county_name`, and (optionally) `city_name` in the config. For analyses outside of Washington, you will also need to specify a different OpenStreetMap extract under `osm_extract`. From http://download.geofabrik.de/, navigate to the smallest possible extract that matches your study area, right-click and select "Copy link address", and copy it to the config. Script (3) prepares spatial data from Seattle-specific sources, so you can either update the code to prepare a table of your own inputs or skip this script entirely.

Script (1) prepares input block boundaries based on data from the US Census. If you are running this analysis for a location outside of the United States, change lines 70-114 in script (1) to load block polygons from a different source. You will also want to choose a different projection that's suitable for your country in `working_crs`.


## Running scripts

All the scripts take a single argument, the path to the configuration file. If you are running the scripts from the command line, you can pass the configuration file path directly, for example:

```
Rscript --vanilla analysis/1_prepare_blocks.R --config_filepath /full/path/to/config.yaml
```

If you prefer to run the scripts interactively (for example, running line-by-line in RStudio), you can instead update the `DEFAULT_CONFIG_FILEPATH` at the top of each script.


### Order of execution

The scripts should be run in order:

1. `1_prepare_blocks.R`: Downloads and formats city block polygons from the US census. Saves two versions, one for analysis and another simplified copy for visualization. Also downloads and prepares the road network and elevation raster needed for the walking time analysis. Saves a bounding box of the analysis area to use in later scripts.

2. `2_prepare_pois_from_openstreetmap.R`: Downloads destinations in the study area from OpenStreetMap based on the OSM location tags in `config$osm_destination_queries`. All OSM destinations are formatted as points in a table containing destination name, destination type, latitude, longitude, and street address. The study area is defined based on the bounding box saved in `1_prepare_blocks.R`.

3. `3_prepare_pois_seattle_specific.R`: Downloads geographic data on parks, libraries, and transit stops from open data sources specific to Seattle. Formats destinations as points in a table containing destination name, destination type, latitude, longitude, and (when available) street address. This script is specific to Seattle data sources---users running analyses for other cities could either adapt this script to their own city-specific data sources or skip it entirely.

4. `4_walking_time_analysis.R`: Loads the data prepared in scripts 1, 2, and (if run) 3, and calculates the lowest travel time from each origin block to each type of destination using the "r5r" R package.

**Users should thoroughly vet the destination data produced by scripts (2) and (3) before running the travel time analysis in script (4).** Publicly-available data sources may be outdated or incomplete, and the travel time analysis can be sensitive to a single missing destination. This is especially true for less-common destination types like grocery stores and libraries.


### Output

Scripts (1), (2), and (3) save formatted origin blocks, city road network data, elevation data, and destination tables to the prepared data folder. The formatted destination tables, `destinations_osm.csv` and `destinations_city_specific.csv`, may be useful to visualize on their own to better understand the distribution of destinations across a city.

Script (4) saves output from the travel time analysis to the results folder:

- (a) `travel_time_results.csv`, a table containing block ID and travel time in minutes to each destination type;
- (b) `travel_time_results_for_viz.geojson`, a GeoJSON (polygons) object containing simplified blocks with the same attributes as the table;
- (c) `travel_time_results_for_viz.js`, a JS file that includes definitions for the GeoJSON object as well as the study area bounding box. This JS file can be copied directly into the `visualization/` folder to update the interactive web map.
