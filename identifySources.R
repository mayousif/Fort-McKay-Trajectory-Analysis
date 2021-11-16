library(rgdal)
library(sf)


# Load trajectory data 
load("5min_backtraj_results.Rdata")


# Load facilities shapefile and convert to UTM coordinates
facilities = st_read("GIS Files\\OS2013_Facilities.shp")
facilities_UTM = st_transform(facilities,CRS("+init=epsg:32612"))


# Fort McKay UTM coordinates 
FMK_long_UTM = 461342
FMK_lat_UTM = 6338012


# Create data frames to store datetimes when trajectory passed over each facility
source_datetimes = as.data.frame(as.POSIXct(names(allResults),format = "%Y-%m-%d %H:%M:%S",tz="MST"))
syncrude_results = as.vector(rep(0,nrow(source_datetimes)))
suncor_results = as.vector(rep(0,nrow(source_datetimes)))
cnrlMJ_results = as.vector(rep(0,nrow(source_datetimes)))
cnrlHorizon_results = as.vector(rep(0,nrow(source_datetimes)))

all_datetimes = source_datetimes[,1]
facility_ID = as.numeric(facilities_UTM$OSP_NO)


# Find times where air over FMK hit each source
for (i in 1:length(allResults)) {
  
  # Temporaily store current trajectory data
  data = allResults[[i]]

  
  # Create point object storing all trajectory points to compare with shapefiles
  point_UTM = st_multipoint(x = as.matrix(data[,2:3])) %>% st_sfc(crs=32612) %>% st_cast("POINT")

  
  # Count number of points intersecting each facility (0 = does not intersect, >0 = intersects)
  suncor_results[all_datetimes %in% data$Datetime[nrow(data)]] =
    sum(st_intersects(st_union(facilities_UTM[facilities_UTM$OSP_NO==8,]),point_UTM,sparse=F))
  syncrude_results[all_datetimes %in% data$Datetime[nrow(data)]] =
    sum(st_intersects(st_union(facilities_UTM[facilities_UTM$OSP_NO==20,]),point_UTM,sparse=F))
  cnrlMJ_results[all_datetimes %in% data$Datetime[nrow(data)]] =
    sum(st_intersects(st_union(facilities_UTM[(facilities_UTM$OSP_NO==3) | (facilities_UTM$OSP_NO==24),]),point_UTM,sparse=F))
  cnrlHorizon_results[all_datetimes %in% data$Datetime[nrow(data)]] =
    sum(st_intersects(st_union(facilities_UTM[facilities_UTM$OSP_NO==7,]),point_UTM,sparse=F))
  
}


# Merge and save data
source_matrix = cbind(source_datetimes,suncor_results,syncrude_results,cnrlMJ_results,cnrlHorizon_results)
colnames(source_matrix)[1] = "Datetime"
save(source_matrix,file = "source_matrix.Rdata")


