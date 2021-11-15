library(rgdal)
library(gstat)


# Read data
wind_data = read.csv("Wind_Data_All_Stations.csv", na = NA)
station_data = read.csv("Station_Locations.csv", na = NA)

# Convert columns to correct format
wind_data$Datetime = as.POSIXct(wind_data$Datetime, format = "%Y-%m-%d %H:%M:%S", tz = "MST")
station_data$STATION = as.character(station_data$STATION)

# Project long/lat coordinates to UTM (planar coordinates)
station_data_sp = SpatialPoints(cbind(station_data[,2], station_data[,3]), 
                                proj4string=CRS("+proj=longlat"))
station_data_UTM = spTransform(station_data_sp, CRS("+init=epsg:32612"))

# Attach UTM coordinates to each station name
stations = cbind(station_data[1],station_data_UTM@coords)

# Initialize result dataframes and dataframes used in the for loop
# Model domain is based on monitoring station locations.
allResults = list()
x_grd = seq(from = min(round(stations[,2],-3)-10000), 
            to = max(round(stations[,2],-3)+10000), 
            by = 1000) # 10 km buffer added to east and west boundaries
y_grd = seq(from = min(round(stations[,3],-3)), 
            to = max(round(stations[,3],-3)), 
            by = 1000)
z = expand.grid(x = x_grd, y = y_grd)
coordinates(z) = ~ x+y
gridded(z) = TRUE

# Calculate a trajectory every 30 minutes, starting 6 hours after first measurement
for (k in seq(from = 1 + 6*12, to = nrow(wind_data)-100000, by  = 12)) {
  
  # Setup temporary dataframe for this trajectory
  allPos = data.frame(matrix(nrow = nrow(wind_data), ncol = 3))
  allPos[,1] = wind_data[,1]
  colnames(allPos) = c("Datetime","x","y")
  
  # Calculate each position of this trajectory (moving backwards through time)
  for (i in k:(k-72)) {
    
    # Set start position to Fort McKay (UTM coordinate system)
    if (i == k) {
      startPos =  t(as.data.frame(c(461313.41,6338011.98)))
    } 
    allPos[i,-1] = startPos
    
    # Isolate wind data at time i
    sample_ws = stations[,2:3]
    sample_wd = stations[,2:3]
    for (j in 1:nrow(stations)) {
      sample_ws[j,3] = wind_data[i,j*2]
      sample_wd[j,3] = wind_data[i,j*2+1]
    }
    colnames(sample_ws) = c("x","y","ws")
    colnames(sample_wd) = c("x","y","wd")
    
    # Split wind data into u and v components
    sample_u = sample_ws[,1:2]
    sample_v = sample_ws[,1:2]
    sample_u[,3] = -sample_ws[,3]*sinpi(sample_wd[,3]/180)
    sample_v[,3] = -sample_ws[,3]*cospi(sample_wd[,3]/180)
    colnames(sample_u) = c("x","y","u")
    colnames(sample_v) = c("x","y","v")
    
    coordinates(sample_u) = ~x+y
    coordinates(sample_v) = ~x+y
    coordinates(sample_ws) = ~x+y
    coordinates(sample_wd) = ~x+y
    
    # if >50% of data is missing, stop
    if (mean(!is.na(sample_u$u)) < 0.5) {
      allResults[[format(wind_data[k,1],"%Y-%m-%d %H:%M:%S")]] = allPos[!(is.na(allPos$x)),]
    }
    
    # Interpolate/extrapolate data across the grid 
    filled_data_u = idw(u~1, locations = sample_u[!is.na(sample_u$u),], newdata = z, debug.level = 0)
    filled_data_v = idw(v~1, locations = sample_v[!is.na(sample_v$v),], newdata = z, debug.level = 0)
    
    filled_data_u_grid = as.data.frame(filled_data_u)
    filled_data_v_grid = as.data.frame(filled_data_v)
    
    # Find which grid value to use based on most recent spatial position
    u_i = filled_data_u_grid[which(filled_data_u_grid$x == round(allPos[i,2],-3) & 
                                       filled_data_u_grid$y == round(allPos[i,3],-3)),3]
    v_i = filled_data_v_grid[which(filled_data_v_grid$x == round(allPos[i,2],-3) & 
                                       filled_data_v_grid$y == round(allPos[i,3],-3)),3]
    
    # Convert u and v back to wind speed/direction at this position
    ws_i = sqrt(u_i^2 + v_i^2)
    
    if (u_i > 0 & v_i > 0) {
      wd_i = 180 + asin(abs(u_i/ws_i))*180/pi
    } else if (u_i > 0 & v_i < 0) {
      wd_i = 270 + acos(abs(u_i/ws_i))*180/pi
    } else if (u_i < 0 & v_i > 0) {
      wd_i = 90 + acos(abs(u_i/ws_i))*180/pi
    } else if (u_i < 0 & v_i < 0) {
      wd_i = asin(abs(u_i/ws_i))*180/pi
    }
    
    # Calc distance travelled in meters for this 5-min interval based on ws/wd
    travelDist = ws_i/3.6*60*5
    travelDir = wd_i
    
    if (travelDir >= 0 & travelDir < 90) {
      
      x = -travelDist*sin((travelDir)*pi/180)
      y = -travelDist*cos((travelDir)*pi/180)
      
    } else if (travelDir >= 90 & travelDir < 180) {
      
      x = -travelDist*sin((180-travelDir)*pi/180)
      y = travelDist*cos((180-travelDir)*pi/180)
      
    } else if (travelDir >= 180 & travelDir < 270) {
      
      x = travelDist*sin((travelDir-180)*pi/180)
      y = travelDist*cos((travelDir-180)*pi/180)
      
    } else if (travelDir >= 270 & travelDir < 360) {
      
      x = travelDist*sin((360-travelDir)*pi/180)
      y = -travelDist*cos((360-travelDir)*pi/180)
      
    }
    
    # If end location is outside grid domain, save and stop
    if (round(startPos[,1]-x,-3) <= min(x_grd) | round(startPos[,1]-x,-3) >= max(x_grd) |
        round(startPos[,2]-y,-3) <= min(y_grd) | round(startPos[,2]-y,-3) >= max(y_grd)) {
      
      allResults[[format(wind_data[k,1],"%Y-%m-%d %H:%M:%S")]] = allPos[!(is.na(allPos$x)),]
      break
    }
    
    # Find end position after this 5-minute interval
    endPos = cbind(startPos[1]-x,startPos[2]-y)
    
    # If 6 hours have passed, save and stop
    if (i == k-72){
      allResults[[format(wind_data[k,1],"%Y-%m-%d %H:%M:%S")]] = allPos[!(is.na(allPos$x)),]
    }
    
    # Set start position for next iteration to be the end position of this iteration
    startPos = endPos
    
    
  }
}

# Write results to .csv file
save(allResults,file="5min_backtraj_results.Rdata")

