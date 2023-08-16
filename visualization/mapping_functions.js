/*
  HELPER FUNCTIONS FOR WEB MAPPING

  Author: Nathaniel Henry, nat@henryspatialanalysis.com
  Created: 15 August 2023

  Description: Functions to facilitate web mapping with Leaflet. Assumes that Leaflet
    (https://unpkg.com/leaflet@1.0.0-rc.2/dist/leaflet.js) has already been sourced.
*/


/*
  Function: Create a leaflet map with one base layer and two overlay layers
*/
function create_choro_map_base(
  map_div_id, ctr = [0,0], bounds = null, minZoom = 0, maxZoom = 20, startZoom = 12,
  attr_addon = ''
){
  // Create basemap
  var basemap = L.map(
    id = map_div_id,
    options = {
      center: ctr, maxBounds: bounds, minZoom: minZoom, maxZoom: maxZoom, zoomDelta: .5,
      keyboardPanDelta: 40, inertia: 1, zoomControl: false
    }
  ).setView(center = ctr, zoom = startZoom);

  // Attribution needed for the map tile layers, plus an optional add-on
  var attr = '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> contributors' +
    ' | Basemap &copy; <a href="https://carto.com/attributions">CARTO</a>' +
    ' | Roads &copy; <a href="http://stamen.com">Stamen</a>' +
    ' (<a href="http://creativecommons.org/licenses/by/3.0">CC BY 3.0</a>)' +
    attr_addon;

  // Add map tile layers
  var CartoDB_PositronNoLabels = L.tileLayer(
    urlTemplate = 'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png',
    options = {subdomains: 'abcd', maxZoom: 20, pane: 'tilePane'}
  ).addTo(basemap);
  var Stamen_TonerLines = L.tileLayer(
    urlTemplate = 'https://stamen-tiles-{s}.a.ssl.fastly.net/toner-lines/{z}/{x}/{y}{r}.png',
    options = {subdomains: 'abcd', maxZoom: 15, opacity: 0.3, pane: 'markerPane', zIndex: 1}
  ).addTo(basemap);
  var CartoDB_PositronOnlyLabels = L.tileLayer(
    urlTemplate = 'https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}{r}.png',
    options = {attribution: attr, subdomains: 'abcd', maxZoom: 20, pane: 'markerPane', zIndex: 2}
  ).addTo(basemap);

  // Return map template
  return basemap;
}


/*
  Class to simplify choropleth color schemes
  limits_asc, labels, and colors should all have the same length
*/
class ColorScheme {
  constructor(limits_asc, colors, labels, na_color = '#888'){
    this.limits = limits_asc;
    this.colors = colors;
    this.labels = labels;
    this.na_color = na_color;
  }
  // Function to construct inner HTML for a legend based on limits and colors
  legend_html() {
    let innerHTML = '';
    for(const ii in [...Array(this.labels.length).keys()]){
      innerHTML += '<b style="background:' + this.colors[ii] + '"></b> ' + this.labels[ii];
      if(ii < (this.labels.length - 1)){
        innerHTML += '<br/>';
      }
    }
    return innerHTML;
  }
}

class ColorSchemeNumeric extends ColorScheme {
  // Function to get colors based on an arbitrary value
  color_from_value(value){
    let val_color = this.na_color;
    for(const ii in [...Array(this.colors.length).keys()]){
      if(value >= this.limits[ii]){
        val_color = this.colors[ii];
      }
    }
    return val_color;
  }
}

class ColorSchemeCategorical extends ColorScheme {
  // Function to get colors based on an arbitrary value
  color_from_value(value){
    let val_color = this.na_color;
    for(const ii in [...Array(this.colors.length).keys()]){
      if(value == this.limits[ii]){
        val_color = this.colors[ii];
      }
    }
    return val_color;
  }
}
