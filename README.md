# Fort McKay Trajectory Analysis
 
These scripts are designed to calculate back-trajectories from Fort McKay, Alberta and detect upwind oil sands facilities. There are two primary scripts, one to calculate the trajectories and another to find which oil sands facilities are intersected by each trajectory. Trajectories are calculated using local wind data from 10 monitring stations maintained by the Wood Buffalo Environmental Association (WBEA). Sample wind data for 2020 is provided (Wind_Data_All_Stations.csv) and can be found here: https://wbea.org/historical-monitoring-data/. Shapefiles for Fort McKay and the surroudning oil sands facilities are also provided.

# Installation and Setup
These scripts were written in R version 4.0+, which is required (https://www.r-project.org/). After installing R, three packages need to be installed (along with their dependecies, which is generally done automatically)"

* "rgdal" (https://cran.r-project.org/web/packages/rgdal/rgdal.pdf)
* "gstat" (https://cran.r-project.org/web/packages/gstat/gstat.pdf)
* "sf" (https://cran.r-project.org/web/packages/sf/sf.pdf)

This can be done with the "install.packages()" function in R.

# File Formatting
Two data files are needed, one storing the coordinates of each location (Station_Locations.csv) and one storing wind data for each station (Wind_Data_All_Stations.csv). The column structure in the files ued should match the structure of the provided sample data. Lattiude and longitude are required to be in the WGS 64 reference system. The datetime column in the wind data file is require to have the following formatting: "yyyy-mm-dd HH:MM:ss".

# Running the Scripts
The first script (calcAllPaths.R) will calculate trajectories every 30-minutes by default and save the data ("5min_backtraj_results.Rdata"). Within each trajectory, positions are calculated on 5-minute intervals, mathcing the measurement frequency of the WBEA stations. It is recommended to calculate trjactories in batches (e.g., <1 year) to avoid computer memory problems.

The output from this first script ("5min_backtraj_results.Rdata") is a named list, with each list entry being a dataframe containing trajectory data (datetime and coordiantes of each point along the trajectory). The name of each list entry indicates the end-time of the trajectory (i.e., when it arrives in Fort McKay). This can be used to quickly find the matching trajectory for a time of interest (e.g., times where pollutant concentrations are elevated). The trajectory calculation has three stop conditions: insufficent data (>= 5 of the 10 stations missing data), moving beyond the pre-defined domain, or after 6 hours pass. The domain is based on station locations, with extra buffer (10 km) added to the east and west boundaries.

The trjacotry data file is also used as an input to "identifySources.R", which counts the number of points that intersect each facility along each trajectory. This can be used to identify which facilities were upwind at a given time. The output file of this script ("source_matrix.Rdata") is a dataframe where the first column contains the end datetimesmes of each trajectory and the remaining columns show the number of points intersecting each source. Therefore, a value of 0 indicates the facility was not upwind at the given time of interest.



