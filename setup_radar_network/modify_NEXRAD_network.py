# The choice of creating a network depends on creating a domain mask of where radars can go.
# The following procedure was used.

# Obtain boundary outline coordinates for the CONUS
# The mask is constructed using the following rules:
# -Mask out area within 100 km of a LAND international border
#   -This tends to cut out portions of the Great Lakes region where radars currently exist (e.g., KDTX, KCLE, and KBUF)
#   -To fix this, grab the Great Lakes shorelines and create a joint polygon from the union of the buffer of all shorelines of about 1.0 deg
#   -Add this back into the grid
# -Also added the Olympic peninsula of NW WA state since there is a water border there that the CONUS boundary shapefile doesn't distinguish
# -Pacific and Atlantic (Gulf of Mexico included) coastlines have no restriction, except for where they meet a land border

from cartopy import crs
from cartopy import feature
from matplotlib import use, colormaps
use('agg')
from netCDF4 import Dataset
import matplotlib.pyplot as plt
import numpy as np
from scipy.stats import qmc
import shapely
from cartopy.io.shapereader import Reader
from geopy import distance
import pandas as pd
from math import sqrt, radians, cos, sin, acos
from sys import exit
from os.path import isfile
from timeit import default_timer
import pickle

max_Cband_radars = 200
#US_radar_list_file = "/work/noaa/wrfruc/jdduda/RadarNext/nexrad-stations-valid-2026.txt"
US_radar_list_file = "/work/noaa/wrfruc/jdduda/RadarNext/networking/US_radars_slimmed_closest_50_pct_A.txt"
network_name = "lose_50pct_fill_1"
final_mask_file = "mask_geometry.pkl"
max_radar_ranges = {'S':460.0,'C':250.0,'X':120.0} # maximum allowable range of data by band letter

maj_axis = distance.ELLIPSOIDS['WGS-84'][1]
min_axis = distance.ELLIPSOIDS['WGS-84'][0]
Re = sqrt(maj_axis*min_axis)*1000.

# Open text file for writing
f_out = open(f"radar_network_{network_name}.txt",'w')
f_out.writelines("ICAO    NAME                           ST COUNTY                         LAT       LON        ELEV    BAND\n")
f_out.writelines("------- ------------------------------ -- ------------------------------ --------- ---------- ------  ---------\n")

def gc1(lon1, lat1, lon2, lat2):

    lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
    dlon = lon2 - lon1
    a = cos(lat1) * cos(lat2) * cos(dlon) + sin(lat1)*sin(lat2)
    if a > 0:
       a = np.minimum(a,1.0)
    else:
       a = np.maximum(a,-1.0)
    dist = Re*acos(a)
    return dist

def gc2d(lon1, lat1, lon2, lat2):
    # Input arguments must be 2D arrays with the same dimensions.
    # Returns a 2D array of distances.

    lon1, lat1, lon2, lat2 = map(np.radians, [lon1, lat1, lon2, lat2])
    dlon = lon2 - lon1
    a = np.cos(lat1) * np.cos(lat2) * np.cos(dlon) + np.sin(lat1)*np.sin(lat2)
    a = np.maximum(-1.0,np.minimum(1.0,a))
    if np.any(np.abs(a) > 1.0):
       print("Problem...a distance is impossible")
       print(a[a > 1.0])
       print(np.argwhere(a > 1.0))
    dist = Re*np.arccos(a)
    return dist

projPC = crs.PlateCarree()
projAE = crs.AlbersEqualArea(central_longitude=-98.5833,central_latitude=39.833,standard_parallels=(30,45))
rng = np.random.default_rng()

# Get terrain and landmask information from nature run grid file
geo_file = "/work/noaa/wrfruc/jdduda/RadarNext/NR_to_MRMS_grid.nc"
nc = Dataset(geo_file,'r')
terrain_height = nc.variables['HGT_M'][:][0,:,:]
landmask = nc.variables['LANDMASK'][:][0,:,:]
nc.close()
# Use that information to calculate terrain gradient/slope
terrain_gradient_vect_2D_i,terrain_gradient_vect_2D_j = np.gradient(terrain_height)
joint_arry = np.vstack((terrain_gradient_vect_2D_i.flatten(),terrain_gradient_vect_2D_j.flatten()))
terrain_gradient_scalar = np.linalg.norm(joint_arry,axis=0)
terrain_gradient_scalar = np.reshape(terrain_gradient_scalar,terrain_height.shape)
# Get CONUS boundary coordinates and set map extent
CONUS_5m_shapefile = "/work/noaa/wrfruc/jdduda/CONUS_shapefiles/cb_2018_us_nation_5m.shp"
reader = Reader(CONUS_5m_shapefile)
CONUS_geometry = next(reader.geometries())
polygons = list(CONUS_geometry.geoms)
conus_geom = max(polygons, key=lambda p: p.area)
CONUS_bounds = conus_geom.bounds
x1 = 0.5*np.floor(CONUS_bounds[0]/0.5)
x2 = 0.5*np.ceil(CONUS_bounds[2]/0.5)
y1 = 0.5*np.floor(CONUS_bounds[1]/0.5)
y2 = 0.5*np.ceil(CONUS_bounds[3]/0.5)
#map_extent = [x1,x2,y1,y2]
map_extent = [x1-1,x2+1,y1-1,y2+1]

# Create MRMS grid
MRMS_lat_1 = 20.005
MRMS_lon_1 = -129.995 # equivalent to 230.005 - 360
MRMS_lat_2 = 54.995
MRMS_lon_2 = -60.005 # equivalent to 299.995 - 360
grid_nx = 7000
grid_ny = 3500
lat1d = np.linspace(MRMS_lat_1,MRMS_lat_2,grid_ny)
lon1d = np.linspace(MRMS_lon_1,MRMS_lon_2,grid_nx)
mrms_lons,mrms_lats = np.meshgrid(lon1d,lat1d)
conus_mask = shapely.contains_xy(conus_geom,mrms_lons,mrms_lats)
#map_extent = [MRMS_lon_1,MRMS_lon_2,MRMS_lat_1,MRMS_lat_2]
dx = Re*np.cos(np.deg2rad(mrms_lats))*radians(0.01)
dy = np.full_like(mrms_lats,Re*radians(0.01))
grid_spacing = np.sqrt(dx*dy)
terrain_slope = np.rad2deg(np.arctan(terrain_gradient_scalar/grid_spacing))

# Creating CONUS mask not near international borders
if isfile(final_mask_file):
   print("Ah! I see the geometry has already been computed. Let's read it in and skip the time-consuming re-computation")
   f = open(final_mask_file,'rb')
   mask_geom = pickle.load(f)
   coastal_geometry_lat_lon = pickle.load(f)
   f.close()
else:
 reader = Reader("/work/noaa/wrfruc/jdduda/CONUS_shapefiles/tl_2019_us_coastline.shp")
 #plt.figure(figsize=(10,4.75))
 #ax = plt.gcf().add_axes([0.001,0.001,0.998,0.998],projection=projPC)
 #ax.add_feature(feature.STATES.with_scale('10m'),linewidth=0.5,edgecolor='0.5')
 #ax.add_feature(feature.BORDERS.with_scale('50m'),linewidth=1,edgecolor='black')
 #ax.add_geometries([conus_geom],crs=projPC,facecolor='none',edgecolor='black',linewidth=1,zorder=1)
 i = 0
 j = 0
 k = 0
 l = 0
 for record in reader.records():
   if "pacific" in record.attributes['NAME'].lower():
      trans_geom = projAE.project_geometry(record.geometry,src_crs=projPC)
      j += 1
      pacific_coast_geom = shapely.buffer(trans_geom,distance=40000.)
#      pacific_coast_geom = shapely.buffer(record.geometry,distance=0.36)
      if j == 1:
         union_pacific_coast_geom = pacific_coast_geom
      else:
         union_pacific_coast_geom = shapely.union(union_pacific_coast_geom,pacific_coast_geom)
   if "atlantic" in record.attributes['NAME'].lower():
      trans_geom = projAE.project_geometry(record.geometry,src_crs=projPC)
      k += 1
      atlantic_coast_geom = shapely.buffer(trans_geom,distance=40000.)
#      atlantic_coast_geom = shapely.buffer(record.geometry,distance=0.36)
      if k == 1:
         union_atlantic_coast_geom = atlantic_coast_geom
      else:
         union_atlantic_coast_geom = shapely.union(union_atlantic_coast_geom,atlantic_coast_geom)
   if "gulf" in record.attributes['NAME'].lower():
      trans_geom = projAE.project_geometry(record.geometry,src_crs=projPC)
      l += 1
      gulf_coast_geom = shapely.buffer(trans_geom,distance=40000.)
#      gulf_coast_geom = shapely.buffer(record.geometry,distance=0.36)
      if l == 1:
         union_gulf_coast_geom = gulf_coast_geom
      else:
         union_gulf_coast_geom = shapely.union(union_gulf_coast_geom,gulf_coast_geom)
   if "great lakes" in record.attributes['NAME'].lower():
      i += 1
#      pacific_coast_geom = shapely.buffer(trans_geom,distance=40000.)
      lake_geom = shapely.buffer(record.geometry,distance=1)
      if i == 1:
         union_lake_geom = lake_geom
      else:
         union_lake_geom = shapely.union(union_lake_geom,lake_geom)
 coastal_geoms = shapely.union_all([union_pacific_coast_geom,union_atlantic_coast_geom,union_gulf_coast_geom])
 coastal_geometry_lat_lon = projPC.project_geometry(coastal_geoms,src_crs=projAE)
 land_border_shpfile = "/work/noaa/wrfruc/jdduda/CONUS_shapefiles/data/DoS_LSIB_v11_4_24Feb2025.shp"
 land_border_reader = Reader(land_border_shpfile)
 for record in land_border_reader.records():
   if ("UNITED STATES" in record.attributes['COUNTRY1'].upper() or "UNITED STATES" in record.attributes['COUNTRY2'].upper()) and \
      ("CANADA" in record.attributes['COUNTRY1'].upper() or "CANADA" in record.attributes['COUNTRY2'].upper()):
      canada_us_border = record.geometry.geoms[0]
      trans_geom = projAE.project_geometry(canada_us_border,src_crs=projPC)
      # Create buffer around border
#      canada_border_buffer_poly = shapely.buffer(record.geometry.geoms[0],distance=0.09,single_sided=False)
      trans_buffer = shapely.buffer(trans_geom,distance=10000.,single_sided=False)
      canada_border_buffer_poly = projPC.project_geometry(trans_buffer,src_crs=projAE)
   if ("UNITED STATES" in record.attributes['COUNTRY1'].upper() or "UNITED STATES" in record.attributes['COUNTRY2'].upper()) and \
      ("MEXICO" in record.attributes['COUNTRY1'].upper() or "MEXICO" in record.attributes['COUNTRY2'].upper()):
      trans_geom = projAE.project_geometry(record.geometry,src_crs=projPC)
      trans_buffer = shapely.buffer(trans_geom,distance=10000.,single_sided=False)
#      mexico_border_buffer_poly = shapely.buffer(record.geometry,distance=0.09,single_sided=False)
      mexico_border_buffer_poly = projPC.project_geometry(trans_buffer,src_crs=projAE)
 geom_difference_canada = shapely.difference(conus_geom,canada_border_buffer_poly)
 geom_difference_mexico = shapely.difference(conus_geom,mexico_border_buffer_poly)

 # Add Olympic peninsula
 olympia_data = np.loadtxt("Olympic_peninsula_boundary.dat")
 olympia_data.astype(float)
 olympia_data[:,[1,0]] = olympia_data[:,[0,1]]
 Olympic_peninsula_poly = shapely.Polygon(olympia_data)
 Olympic_peninsula_geom = shapely.intersection(Olympic_peninsula_poly,geom_difference_mexico)

 # Construct final mask
 piece3 = shapely.intersection(union_lake_geom,geom_difference_mexico)
 piece4 = shapely.intersection(geom_difference_canada,geom_difference_mexico)
 # FINAL MASK
 mask_geom = shapely.union_all([piece3,piece4,Olympic_peninsula_geom])
 f = open("mask_geometry.pkl",'wb')
 pickle.dump(mask_geom,f)
 pickle.dump(coastal_geometry_lat_lon,f)
 f.close()
 # FINAL MASK
 # Plot parts of the mask for diagnostics
 #ax.add_geometries(union_lake_geom,crs=projPC,facecolor='none',edgecolor='salmon',linewidth=0.5,zorder=2)
 #ax.add_geometries(geom_difference_canada,crs=projPC,facecolor='none',edgecolor='orange',linewidth=0.5,zorder=2)
 #ax.add_geometries(geom_difference_mexico,crs=projPC,facecolor='none',edgecolor='lime',linewidth=0.5,zorder=2)
 #ax.add_geometries(mask_geom,crs=projPC,facecolor='lightsteelblue',edgecolor='none',linewidth=1,zorder=1)
 #ax.set_extent(map_extent,crs=projPC)
 #plt.savefig("masked_CONUS_radar_domain.png",dpi=200)
 #plt.close()
# End read or build mask geometry

# Mask MRMS grid to CONUS mask constructed above...no radars can be placed outside of this masked area
final_mask = shapely.contains_xy(mask_geom,mrms_lons,mrms_lats)

fig_x = 10
AR = (map_extent[3]-map_extent[2])/(map_extent[1]-map_extent[0])
fig_y = AR*fig_x+1.5

# Grab radar site information
df = pd.read_table(US_radar_list_file,sep="\s+",header=0,skiprows=[1],index_col='ICAO')
radar_sites_dict = df.to_dict(orient='index')
radar_sites_keys = list(radar_sites_dict.keys())
n_nexrads = len(radar_sites_dict)
radar_coords_first_guess = np.full((n_nexrads,2),np.nan,dtype=float)
radar_coords_first_guess[:,0] = df['LON'].values
radar_coords_first_guess[:,1] = df['LAT'].values
if False:
 coastal_radars = shapely.contains_xy(coastal_geometry_lat_lon,radar_coords_first_guess[:,0],radar_coords_first_guess[:,1])
 inland_radars = ~coastal_radars
for a in range(n_nexrads):
   name = df.index[a]
   ICAO = name
   NAME = df['NAME'].loc[name].replace(" ","_")
   ST = df['ST'].loc[name]
   COUNTY = df['COUNTY'].loc[name].replace(" ","_")
   LAT = df['LAT'].loc[name]
   LON = df['LON'].loc[name]
   ELEV = df['ELEV'].loc[name]
#   BAND = "C"
#   if coastal_radars[a]:
#      print(f"{df.iloc[a]['NAME']} ({df.index[a]}) is along the shoreline")
   BAND = "S"
   f_out.writelines(f"{ICAO:<7s} {NAME:30s} {ST} {COUNTY:30s} {LAT:<9.5f} {LON:<10.5f} {ELEV:>6.0f} {BAND}\n")
# Florence_OR_radar = [-124.045287, 43.962198] # Elevation 620 ft ASL, Lane County...add this to shorebound radars
# radar_coords_first_guess = np.vstack((radar_coords_first_guess,Florence_OR_radar))
# FLORENCE = "FLORENCE"
# LANE = "LANE"
# f_out.writelines(f"KFLO    {FLORENCE:30s} OR {LANE:30s} 43.96220   -124.04529    620 S\n")
radar_coords = radar_coords_first_guess.copy()

# Compute spacing between all pairs of first-guess radars
timea = default_timer()
network_spacing = np.full((n_nexrads,n_nexrads),np.nan,dtype=float)
for a in range(n_nexrads):
 for b in range(n_nexrads):
  network_spacing[a,b] = gc1(radar_coords_first_guess[a,0],radar_coords_first_guess[a,1],radar_coords_first_guess[b,0],radar_coords_first_guess[b,1])
np.fill_diagonal(network_spacing,np.inf)
# For each radar determine the distance to its nearest neighbor as well as which radar that is
closest_radar = np.min(network_spacing,axis=1)
closest_radar_b = np.argmin(network_spacing,axis=1)
# Setup 2D array of distances from each grid point to nearest radar
network_distances = np.full(mrms_lons.shape,1e7,dtype=float)
distances_masked = np.ma.masked_where(~final_mask,network_distances)
# Loop through radars and eliminate radars that are either outside the CONUS (mask) or are too close to others
for a in range(n_nexrads):
# if coastal_radars[a]:
    distances = gc2d(mrms_lons,mrms_lats,radar_coords_first_guess[a,0],radar_coords_first_guess[a,1])
#    network_distances = np.minimum(network_distances,distances)
    distances_masked = np.ma.minimum(distances_masked,distances)
# else:
#    distances = gc2d(mrms_lons,mrms_lats,radar_coords_first_guess[a,0],radar_coords_first_guess[a,1])
#    network_distances = np.minimum(network_distances,distances)
#    distances_masked = np.ma.minimum(distances_masked,distances)
#distances = gc2d(mrms_lons,mrms_lats,Florence_OR_radar[0],Florence_OR_radar[1])
distances_masked = np.ma.minimum(distances_masked,distances)
distances_masked.mask = ~final_mask
timeb = default_timer()
print(f"It took {timeb-timea:.1f} s to calculate the 2D distances grid")

distance_levs = np.arange(25.,1001.,25.)
plt.figure(figsize=(fig_x,fig_y))
ax = plt.gcf().add_axes([0.01,0.01,0.98,0.98],projection=projPC)
ax.add_feature(feature.STATES.with_scale('10m'),linewidth=0.5,edgecolor='0.5')
ax.add_feature(feature.BORDERS.with_scale('50m'),linewidth=1,edgecolor='black')
ct = ax.contourf(mrms_lons,mrms_lats,distances_masked/1e3,levels=distance_levs,cmap='gnuplot_r',extend='both',transform=projPC)
#print(ct.allsegs)
#for path in ct.get_paths():
#   print(path)
cb = plt.colorbar(mappable=ct,orientation='horizontal',fraction=0.1,aspect=40,pad=0.01,shrink=0.5,ticks=distance_levs,extend='both')
cb.set_label("Distance to closest radar [km]",fontsize=8)
cb.ax.tick_params(labelsize=6)
for a in range(n_nexrads):
  ax.plot(radar_coords_first_guess[a,0],radar_coords_first_guess[a,1],'.',ms=4,color='navy',transform = projPC)
ax.set_extent(map_extent)
plt.savefig(f"NEXRAD_slim_50pct_distances.png",dpi=200)
plt.close()

# Replace first guess radars either outside the CONUS masking domain or that are too close to others
n_added_radars = 0
while np.ma.max(distances_masked) > 125000. and n_added_radars < max_Cband_radars:
# Add new radars at the location of the maximum distance from existing radars, provided that location is not over water or steep terrain
   sorted_idx = np.ma.argsort(distances_masked.flatten(),endwith=False)[::-1]
#   print(len(sorted_idx),sorted_idx[:15])
   for I in range(len(sorted_idx)):
     idx_x,idx_y = np.unravel_index(sorted_idx[I],distances_masked.shape)
#     print(sorted_idx[I],idx_x,idx_y)
     if not distances_masked.mask[idx_x,idx_y]:
#        print(I,len(sorted_idx),sorted_idx[I],idx_x,idx_y,distances_masked[idx_x,idx_y])
        # Find out if this gridpoint is on too much a slope or over a body of water
        if landmask[idx_x,idx_y] == 0 or terrain_slope[idx_x,idx_y] >= 5.0:
         if landmask[idx_x,idx_y] == 0:
           print(f"Cannot place radar at this location ({mrms_lons[idx_x,idx_y]:.3f},{mrms_lats[idx_x,idx_y]:.3f}) since it is over water (landmask = {landmask[idx_x,idx_y]})")
           continue
         elif terrain_slope[idx_x,idx_y] >= 5.0:
           print(f"Cannot place radar at this location ({mrms_lons[idx_x,idx_y]:.3f},{mrms_lats[idx_x,idx_y]:.3f}) since it is on steep terrain with slope {terrain_slope[idx_x,idx_y]:.2f})")
           continue
        else:
         print(f"A radar will be added at lat = {mrms_lons[idx_x,idx_y]}, lon = {mrms_lats[idx_x,idx_y]}")
         break
     else:
        print("Proposed radar outside of acceptable domain. Moving on")
   if I == len(sorted_idx)-1:
      print("CRTICAL PROBLEM: Ran out of possible places to put a new radar...all available spots are over water or steep terrain!")
      exit(1)
   radar_coords = np.vstack((radar_coords,np.array([mrms_lons[idx_x,idx_y],mrms_lats[idx_x,idx_y]])))
   n_added_radars += 1
   print(n_added_radars,radar_coords[-1,0],radar_coords[-1,1])
   f_out.writelines(f"CRAD{n_added_radars:03d} ADDED_C-BAND_{n_added_radars:03d}               ST CO                            {radar_coords[-1,1]:9.5f}  {radar_coords[-1,0]:<10.5f} {terrain_height[idx_x,idx_y]*3.281:>6.0f} C\n")
   distances = gc2d(mrms_lons,mrms_lats,radar_coords[-1,0],radar_coords[-1,1])
   distances_masked = np.ma.minimum(distances_masked,distances)
   distances_masked.mask = ~final_mask
n_radars = len(radar_coords)
print(f"Broke out of loop. Added {n_added_radars}, which makes the total radar count {n_radars}")
print(radar_coords.shape)

# Before plotting final radar sites, re-calculate distance map for locations within CONUS
#timea = default_timer()
#network_distances = np.full(mrms_lons.shape,1e7,dtype=float)
#distances_masked = np.ma.masked_where(~final_mask,network_distances)
#for a in range(n_radars):
#   radar_distance = gc2d(mrms_lons,mrms_lats,radar_coords[a,0],radar_coords[a,1])
#   distances_masked = np.minimum(distances_masked,radar_distance)
#   distances_masked.mask = ~conus_mask
#timeb = default_timer()
#print(f"It took {timeb-timea:.1f} s to calculate the final distance array")
print(f"The largest distance any one point in the domain is from a radar is {np.ma.max(distances_masked)/1e3:.1} km")
plt.figure(figsize=(fig_x,fig_y))
ax = plt.gcf().add_axes([0.01,0.01,0.98,0.98],projection=projPC)
ax.add_feature(feature.STATES.with_scale('10m'),linewidth=0.5,edgecolor='0.5')
ax.add_feature(feature.BORDERS.with_scale('50m'),linewidth=1,edgecolor='black')
ct = ax.contourf(mrms_lons,mrms_lats,distances_masked/1e3,levels=distance_levs,cmap='gnuplot_r',extend='both',transform=projPC)
ax.plot(radar_coords[:,0],radar_coords[:,1],'.',ms=4,color='navy',transform = projPC)
cb = plt.colorbar(mappable=ct,orientation='horizontal',fraction=0.1,aspect=40,pad=0.01,shrink=0.5,ticks=distance_levs)
cb.set_label("Distance to closest radar [km]",fontsize=8)
cb.ax.tick_params(labelsize=6)
ax.add_geometries([conus_geom],crs=projPC,facecolor='none',edgecolor='lime')
ax.set_extent(map_extent)
img_file = f"radar_network_{network_name}.png"
plt.savefig(img_file,dpi=200)
plt.close()

# Close final file
f_out.close()

print("Complete")
