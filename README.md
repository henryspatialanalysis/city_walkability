# "15-minute city" reproduction package

Earlier this year, I published an article on my blog titled _[Is Seattle a 15-minute city? It depends on where you want to walk](https://nathenry.com/writing/2023-02-07-seattle-walkability.html)_. The article got a lot of interest both online and in the [Seattle](https://www.seattletimes.com/seattle-news/politics/is-your-part-of-seattle-a-15-minute-neighborhood-check-out-this-map/) [news](https://www.youtube.com/watch?v=OolmqRna8ds), and a fair number of people reached out asking to replicate the analysis for their own city.

[![Screenshot of the interactive web map](example_map.png)](https://nathenry.com/writing/2023-02-07-seattle-walkability.html#walkability)

The goal of this reproduction package is to empower other people to create their own accessibility analyses tailored to different cities and contexts. Following the instructions in this repository, using only free tools and pulling from publicly-available data, you can create your own interactive web map that shows travel times to the nearest amenities in your city.


## How to use this repository

This project can be broken into two discrete parts: in the `analysis/` folder, we download the origin city blocks, destination amenities, and calculate the travel time between them. In the `visualization/` folder, we use the outputs from that analysis to build an interactive web map where users can visualize travel times to different combinations of amenities. Each folder has its own `README.md` file with step-by-step instructions. If you're not familiar with Git but want to explore this code further, you can download the entire repository by clicking the "Code" button above and selecting "Download ZIP".

The `analysis/` folder requires some software installs to get started, including R, Java, and the Osmosis command line tool for OpenStreetMaps (see the README in that folder for details). After installing the required software and packages, and tweaking a few folder paths in the configuration file, you should be able to run through the four R scripts in order to produce a full walkability analysis for Seattle. A few additional tweaks to the configuration file should allow you to move that analysis to any other city in the US. For cities outside the US, you will need to load city block boundaries from a different source (this project loads them from the US Census), but the general workflow will be the same.

The `visualization/` folder contains example results for Seattle generated from the analysis scripts, `travel_time_results_for_viz.js`; three other Javascript and CSS helper files for producing the interactive map; and `index.html`, which brings them all together in a simple web template. Once you download this repository, you should be able to open `index.html` in your web browser to see the example map for Seattle. When you run your own analysis, simply copy `travel_time_results_for_viz.js` from your results folder into the visualization folder to update the interactive map.

If you would like some help to replicate or expand this analysis for your own city, let's talk! Please [get in touch with me](https://henryspatialanalysis.com/get-in-touch.html) to discuss your project ideas and needs.


## Changes from the original article



### Switching from OpenRouteServer to R5

### Slightly different destinations

