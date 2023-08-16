# 15-minute city visualization

The files in this folder create an interactive map showing walking times to different combinations of amenities across a city.

## Files

- `index.html`: Refers to all other files in this folder. Load this file in your web browser to view the map.
- `mapping_functions.js`: Functions to create an interactive choropleth map using Leaflet.js
- `map_styling.css`: CSS style sheet for interactive maps
- `travel_time_results_for_viz.js`: Defines two objects that are used in the map:
        * `bounding_box`: sets the map boundaries, starting position, and starting zoom
        * `travel_time`: GeoJSON object containing block boundaries and travel time to each amenity type.
- `build_walking_access_maps.js`: Builds on the functions from `mapping_functions.js` and the data from `travel_time_results_for_viz.js` to create the interactive travel time map.

The current `travel_time_results_for_viz.js` file is an example data file showing walking times for Seattle. **To change the map to a different city, run the scripts in the `../analysis/` folder and copy the newly-created `travel_time_results_for_viz.js` file into this folder.**

## Editing map data and styles

The `index.html` currently describes just the map, but other elements can be added around it. The relevant elements in `index.html` could also be copied into an existing web page, as long that page references the same CSS and Javascript files.

The potential destinations are automatically generated based on the properties in the first element of `travel_time.features`. The properties "GEOID" and "population" are automatically skipped---to change which properties get skipped, edit the `skip_fields` array on line 42 of `build_walking_access_maps.js`.

To edit the legend, change the definition of `ttColorScheme` on lines 11-18 of `build_walking_access_maps.js`.
