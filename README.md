# 15-minute city analysis: reproduction package

The goal of this reproduction package is to empower other people to create their own accessibility analyses tailored to different cities and contexts. Following the instructions in this repository, using only free tools and pulling from publicly-available data, you can create your own interactive web map that shows walking times to the nearest amenities in your city.

[![Screenshot of the interactive web map](example_map.png)](https://nathenry.com/writing/2023-02-07-seattle-walkability.html#walkability)

For more details on this repository, see the announcement on the [Henry Spatial Analysis website](https://henryspatialanalysis.com/news/2023-08-16-walkability-tutorial.html).

**If you would like help replicating or expanding this analysis for your own city, let's talk!** This code can be adapted to explore many other aspects of multi-modal transit accessibility across cities. Please [get in touch](https://henryspatialanalysis.com/get-in-touch.html) to discuss your project ideas and needs.


## How to use this repository

This project is broken into two parts: in the `analysis/` folder, we download the origin city blocks, destination amenities, and calculate the travel time between them. In the `visualization/` folder, we use the outputs from that analysis to build an interactive web map where users can visualize travel times to different combinations of amenities. Each folder has its own `README.md` file with step-by-step instructions.

If you're not familiar with Git but want to explore this code further, you can download the entire repository by clicking the "Code" button above and selecting "Download ZIP".

After installing some free software tools and tweaking a few folder paths in the configuration file, you should be able to run through the four R scripts in the `analysis/` folder to produce a full walkability analysis for Seattle. A few additional tweaks to the configuration file will allow you to move that analysis to any other city in the US. For cities outside the US, you will need to load city block boundaries from a different source (this project loads them from the US Census), but the general workflow will be the same.

The `visualization/` folder contains example results for Seattle generated from the analysis scripts; other Javascript and CSS helper files for producing the interactive map; and `index.html`, which displays the map. Once you download this repository, you should be able to open `index.html` in your web browser to see the example map for Seattle. You can also view a copy of the example map [here](https://henryspatialanalysis.com/assets/news/walkability_tutorial_results/). When you run your own analysis, simply copy the results from your results folder into `visualization/` to update the interactive map.
