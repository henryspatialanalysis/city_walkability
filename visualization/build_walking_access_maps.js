/*
  BUILD TRAVEL TIME INTERACTIVE MAP

  CREATED: 15 August 2023
  AUTHOR: Nat Henry
  PURPOSE: Create interactive choropleth maps based on the data saved to
    'travel_time_results_for_viz.js'
*/

// Set up travel time style
var ttColorScheme = new ColorSchemeNumeric(
  limits_asc = [0, 5, 10, 15, 20, 25, 30],
  colors = ["#0868ac", "#5aabac", "#abedab", "#fda668", "#dd643c", "#b8432e", "#999999"],
  labels = [
    'Under 5 min', '5 - 10 min', '10 - 15 min', '15 - 20 min', '20 - 25 min',
    '25 - 30 min', 'Over 30 min'
  ]
);
var tt_legend_html = (
  '<p style="text-align:center; margin:0px 0px 4px 0px; line-height:16px;">' +
  '<strong>Walking time</strong></p>' +
  ttColorScheme.legend_html()
);
function tt_style(feature) {
  return {
    fillColor: ttColorScheme.color_from_value(feature.properties.tt),
    weight: .25, opacity: 1, color: '#222', fillOpacity: .9
  };
}


// Populate dropdown menus based on contents of the travel_time object ------------------>

function format_label(tag){
  var with_spaces = tag.replaceAll('_', ' ');
  var capitalized = with_spaces.charAt(0).toUpperCase() + with_spaces.slice(1);
  return(capitalized)
}

var destination_labels = {};
var destinations_array = [];
const skip_fields = ['GEOID', 'population'];
for(tt_property in travel_time.features[1].properties){
  if(!skip_fields.includes(tt_property)){
    destination_labels[tt_property] = format_label(tt_property);
    destinations_array.push(tt_property);
  }
}

var destination_selection_form = document.getElementById('walkselect');
function add_option(opt_id, opt_name, target){
  var list_item = document.createElement('li');
  list_item.setAttribute('class', 'blank-list');
  var checkbox = document.createElement('input');
  checkbox.type = 'checkbox';
  checkbox.id = opt_id;
  checkbox.name = opt_id;
  checkbox.setAttribute('class', 'destcheckbox');
  var lab = document.createElement('label');
  lab.setAttribute('for', opt_id);
  lab.innerHTML = " " + opt_name;
  list_item.appendChild(checkbox);
  list_item.appendChild(lab);
  target.appendChild(list_item);
}

for(dest in destination_labels){
  add_option(dest, destination_labels[dest], destination_selection_form);
}

var map_terms = [];
if(destinations_array.includes('supermarkets')){
  map_terms.push('supermarkets');
} else {
  map_terms.push(destinations_array[0]);
}

map_terms.forEach((checked_id) => {
  document.getElementById(checked_id).checked = true;
});


// Helper functions to succinctly make and update maps ---------------------------------->

// Function to get all map names to consider based on checked boxes
function get_map_terms(){
  var checked_ids = [];
  for(dest in destination_labels){
    if(document.getElementById(dest).checked){
      checked_ids.push(dest);
    }
  }
  return(checked_ids)
}

// Function to update overall travel time based on selected destinations
update_travel_times = function(layer, destinations){
  // Layer must contain a 'feature' key
  if('feature' in layer){
    if(destinations.length == 0){
      // Case: no destinations selected
      layer.feature.properties.tt = 999;
    } else {
      // Case: at least one destination selected
      layer.feature.properties.tt = 0;
      destinations.forEach((destination) => {
        layer.feature.properties.tt = Math.max(
          layer.feature.properties.tt, layer.feature.properties[destination]
        );
      });
    }
  }
  return(layer)
}

// Interaction functions for features
function highlightFeature(e){
  var layer = e.target;
  layer.setStyle(style = {weight: 3});
  if (!L.Browser.ie && !L.Browser.opera && !L.Browser.edge) {
    layer.bringToFront();
  }
  info.update(layer.feature.properties);
}
function resetHighlight(e){
  var layer = e.target;
  layer.setStyle(style = {weight: .25});
  info.update();
}
function onEachFeature(feature, layer){
  layer.on({
    mouseover: highlightFeature,
    mouseout: resetHighlight
  });
}


// Create a polygon block map based on travel times ------------------------------------->

// Create the basemap
var walkability_map = create_choro_map_base(
  map_div_id = 'walkability',
  ctr = [bounding_box.ymid, bounding_box.xmid],
  bounds = [[bounding_box.ymin, bounding_box.xmin], [bounding_box.ymax, bounding_box.xmax]],
  minZoom = 11, maxZoom = 16, startZoom = bounding_box.zoom,
  attr_addon = ''
);

// Add legend to bottom right
var legend = L.control(options = {position: 'bottomright'});
legend.onAdd = function(map){
  var div = L.DomUtil.create(tagname = 'div', classname = 'leafinfo leaflegend');
  div.innerHTML = tt_legend_html;
  return div;
}
legend.addTo(walkability_map);

// Add info box to top right
var info = L.control(options = {position: 'topright'});
info.onAdd = function(map){
    this._div = L.DomUtil.create(tagname = 'div', classname = 'leafinfo movebox');
    this.update();
    return this._div;
};
info.update = function(feature){
  var tt_label = 0;
  var destination_label = '';
  if((feature == null) | (map_terms.length == 0)){
    this._div.innerHTML = '<h4>Select destinations, then<br/>hover over a tract for details</h4>';
  } else {
    this._div.innerHTML = '<h4 style="margin:0px;"><u>Walking time</u></h4>';
    for(d of map_terms){
      destination_label = destination_labels[d];
      // Format walking time
      if(feature[d] < 5){
        tt_label = '<5 min.';
      } else if(feature[d] > 30){
        tt_label = '>30 min.';
      } else {
        tt_label = Math.round(feature[d]) + ' min.';
      }
      // Add to inner div
      this._div.innerHTML += (
        '<p style="margin:0px;">'+ destination_label + ': ' + tt_label + '</p>'
      );
    }
  }
};
info.addTo(walkability_map);

// Add polygon layer
var largePadding = L.svg(options = {padding: 2.0});
var data_layer = L.geoJson(
  geojson = travel_time,
  options = {
    style: tt_style, pane: 'shadowPane', renderer: largePadding,
    onEachFeature: onEachFeature
  }
)
data_layer.eachLayer((layer) => update_travel_times(layer, map_terms));
data_layer.setStyle(tt_style);
data_layer.addTo(walkability_map);


// Auto-update maps whenever a checkbox is changed -------------------------------------->

var all_checkboxes = document.querySelectorAll(".destcheckbox").forEach(item =>
  item.addEventListener('input', function(){
    map_terms = get_map_terms();
    data_layer.eachLayer((layer) => update_travel_times(layer, map_terms));
    data_layer.setStyle(tt_style);
  })
);
