import numpy as np
from matplotlib import use, colormaps, colors
from cartopy import config
import cartopy.crs as ccrs
import cartopy.feature as cfeature
use('agg')
import matplotlib.pyplot as plt
from sys import exit
from netCDF4 import Dataset
from os.path import isfile, getsize
config['data_dir'] = "/work/noaa/wrfruc/jdduda/cartopy_shapefiles"
from timeit import default_timer

#mask_name = "_slim_50pct_fill_1"
mask_name = "_slim_20pct_B"
mask_file = f"/work/noaa/wrfruc/jdduda/RadarNext/masking/radar_mask{mask_name}.nc"
MRMS_heights = [0.50,0.75,1.0,1.25,1.50,1.75,2.0,2.25,2.50,2.75,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5,8.0,8.5,9.0,10.,11.,12.,13.,14.,15.,16.,17.,18.,19] # [km]

MRMS_lat_1 = 20.005
MRMS_lon_1 = -129.995 # equivalent to 230.005 - 360
MRMS_lat_2 = 54.995
MRMS_lon_2 = -60.005 # equivalent to 299.995 - 360
grid_nx = 7000
grid_ny = 3500
lat1d = np.linspace(MRMS_lat_1,MRMS_lat_2,grid_ny)
lon1d = np.linspace(MRMS_lon_1,MRMS_lon_2,grid_nx)
grid_lons, grid_lats = np.meshgrid(lon1d,lat1d)

ncm = Dataset(mask_file,'r')
mask = ncm.variables['mask'][:]
fl = open(f"mask{mask_name}_coverage.txt",'w')
fl.writelines(f"This radar mask has {np.count_nonzero(mask == 1):,} points that are covered (out of a possible {grid_nx*grid_ny*len(MRMS_heights):,}). That's {100*np.count_nonzero(mask == 1)/(grid_nx*grid_ny*len(MRMS_heights)):.3f}%\n")
for i in range(len(MRMS_heights)):
   nnn = np.count_nonzero(mask[i,:,:] == 1)
   fl.writelines(f"Level {i} ({MRMS_heights[i]*1e3:.0f} m) is covered at {nnn} points ({100*nnn/(grid_nx*grid_ny):.3f} %)\n")
fl.close()
elevs3d = ncm.variables['elevation_angle'][:]
slants3d = ncm.variables['slant_range'][:]
radar_ID = ncm.variables['illuminated_radar_ID'][:]
min_dist3d = ncm.variables['illuminated_min_distance'][:]
n_radars = ncm.radar_count
ncm.close()

proj_PC = ccrs.PlateCarree()
proj_LCC = ccrs.LambertConformal(central_latitude=40,central_longitude=-97.5,cutoff=15)
map_extent = [-123,-68,22,54]
map_aspect = (map_extent[3]-map_extent[2])/(map_extent[1]-map_extent[0])
fig_x = 10
cbar_fract = 0.10
adj_pct = 0.20
# For lambert conformal plots, the actual aspect ratio of the plotted geographical area is smaller (closer to 1.0) than what is calculated based on the extent variable, so adjust accordingly
total_y = fig_x * ((1-adj_pct)*map_aspect + adj_pct)
fig_y = total_y / (1-cbar_fract)

print(map_aspect,fig_x,total_y,fig_y)
mask_cmap = colors.ListedColormap(['none', 'red'])
norm = colors.BoundaryNorm([-2, 0.5, 1.5], mask_cmap.N)

cmap = colormaps['magma_r']
distance_levs = np.arange(25.,600.1,25.)
distance_colors = cmap(np.linspace(0,1,len(distance_levs)+1))

cmap = colormaps['jet']
ID_colors = cmap(np.linspace(0,1,n_radars))
ID_norm = colors.BoundaryNorm(np.arange(0.5,n_radars+0.51,1.0),n_radars)

cmap = colormaps['brg']
angle_levs = [1,2,3,4,5,7.5,10,15,20,30,60,75]
angle_colors = cmap(np.linspace(0,1,len(angle_levs)+1))

for i,z in enumerate(MRMS_heights):
 print(f"Plotting mask products at height {1e3*z:.0f} km...")
 plt.figure(figsize=(fig_x,total_y))
 ax = plt.gcf().add_axes([0.0,0.0,1.0,1.0],projection=proj_LCC)
 ax.set_extent(map_extent,crs=proj_PC)
 ax.coastlines(linewidth=0.5,resolution='50m')
 ax.add_feature(cfeature.BORDERS.with_scale('50m'),edgecolor='black',linewidth=1,zorder=1)
 ax.add_feature(cfeature.STATES.with_scale('10m'),edgecolor='0.25',linewidth=0.5,zorder=2)
 ax.pcolormesh(grid_lons,grid_lats,mask[i,:,:],cmap=mask_cmap,norm=norm,shading='nearest',transform=proj_PC)
 plt.figtext(0.01,0.01,f"Height: {1e3*z:.0f} m",ha='left',va='bottom',fontsize=10,fontweight=500,bbox={'facecolor':'white','edgecolor':'black','pad':3})
 plt.savefig(f"radar_mask{mask_name}_{z*1e3:05.0f}m.png",dpi=150)
 plt.close()

 plt.figure(figsize=(fig_x,fig_y))
 ax = plt.gcf().add_axes([0.0,cbar_fract,1.0,1-cbar_fract],projection=proj_LCC)
 ax.set_extent(map_extent,crs=proj_PC)
 ax.coastlines(linewidth=0.5,resolution='50m')
 ax.add_feature(cfeature.BORDERS.with_scale('50m'),edgecolor='black',linewidth=1,zorder=1)
 ax.add_feature(cfeature.STATES.with_scale('10m'),edgecolor='0.25',linewidth=0.5,zorder=2)
 cf = ax.contourf(grid_lons,grid_lats,np.where(mask[i,:,:] == 1,slants3d[i,:,:]/1e3,np.nan),levels=distance_levs,colors=distance_colors,extend='both',transform=proj_PC)
 cax = plt.gcf().add_axes([0.1,cbar_fract*0.66,0.8,0.02])
 cb = plt.colorbar(mappable=cf,cax=cax,orientation='horizontal',ticks=distance_levs)
 cb.ax.tick_params(labelsize=6)
 cb.set_label(f"Slant range to nearest radar at height = {z} km",fontsize=8)
 plt.figtext(0.01,0.01,f"Height: {1e3*z:.0f} m",ha='left',va='bottom',fontsize=10,fontweight=500,bbox={'facecolor':'white','edgecolor':'black','pad':3})
 plt.savefig(f"radar_mask{mask_name}_slant_range_{z*1e3:05.0f}m.png",dpi=200)
 plt.close()

 plt.figure(figsize=(fig_x,fig_y))
 ax = plt.gcf().add_axes([0.0,cbar_fract,1.0,1-cbar_fract],projection=proj_LCC)
 ax.set_extent(map_extent,crs=proj_PC)
 ax.coastlines(linewidth=0.5,resolution='50m')
 ax.add_feature(cfeature.BORDERS.with_scale('50m'),edgecolor='black',linewidth=1,zorder=1)
 ax.add_feature(cfeature.STATES.with_scale('10m'),edgecolor='0.25',linewidth=0.5,zorder=2)
 cf = ax.contourf(grid_lons,grid_lats,np.where(mask[i,:,:] == 1,min_dist3d[i,:,:]/1e3,np.nan),levels=distance_levs,colors=distance_colors,extend='both',transform=proj_PC)
 cax = plt.gcf().add_axes([0.1,cbar_fract*0.66,0.8,0.02])
 cb = plt.colorbar(mappable=cf,cax=cax,orientation='horizontal',ticks=distance_levs)
 cb.ax.tick_params(labelsize=6)
 cb.set_label(f"Distance to nearest radar at height = {z} km [km]",fontsize=8)
 plt.figtext(0.01,0.01,f"Height: {1e3*z:.0f} m",ha='left',va='bottom',fontsize=10,fontweight=500,bbox={'facecolor':'white','edgecolor':'black','pad':3})
 plt.savefig(f"radar_mask{mask_name}_min_dist_{z*1e3:05.0f}m.png",dpi=200)
 plt.close()

 plt.figure(figsize=(fig_x,fig_y))
 ax = plt.gcf().add_axes([0.0,cbar_fract,1.0,1-cbar_fract],projection=proj_LCC)
 ax.set_extent(map_extent,crs=proj_PC)
 ax.coastlines(linewidth=0.5,resolution='50m')
 ax.add_feature(cfeature.BORDERS.with_scale('50m'),edgecolor='black',linewidth=1,zorder=1)
 ax.add_feature(cfeature.STATES.with_scale('10m'),edgecolor='0.25',linewidth=0.5,zorder=2)
 cf = ax.contourf(grid_lons,grid_lats,np.where(mask[i,:,:] == 1,elevs3d[i,:,:],np.nan),levels=angle_levs,colors=angle_colors,extend='both',transform=proj_PC)
 cax = plt.gcf().add_axes([0.1,cbar_fract*0.66,0.8,0.02])
 cb = plt.colorbar(mappable=cf,cax=cax,orientation='horizontal',ticks=angle_levs)
 cb.ax.tick_params(labelsize=6)
 cb.set_label(rf"Elevation angle ($\degree$) to radar illuminating this grid point at height = {z} km",fontsize=8)
 plt.figtext(0.01,0.01,f"Height: {1e3*z:.0f} m",ha='left',va='bottom',fontsize=10,fontweight=500,bbox={'facecolor':'white','edgecolor':'black','pad':3})
 plt.savefig(f"radar_mask{mask_name}_elev_angle_{z*1e3:05.0f}m.png",dpi=200)
 plt.close()

 plt.figure(figsize=(fig_x,fig_y))
# ax = plt.gcf().add_axes([0.0,cbar_fract,1.0,1-cbar_fract],projection=proj_LCC)
 ax = plt.gcf().add_axes([0.0,0.0,1.0,1.0],projection=proj_LCC)
 ax.set_extent(map_extent,crs=proj_PC)
 ax.coastlines(linewidth=0.5,resolution='50m')
 ax.add_feature(cfeature.BORDERS.with_scale('50m'),edgecolor='black',linewidth=1,zorder=1)
 ax.add_feature(cfeature.STATES.with_scale('10m'),edgecolor='0.25',linewidth=0.5,zorder=2)
 cf = ax.pcolormesh(grid_lons,grid_lats,np.where(radar_ID[i,:,:] > 0,radar_ID[i,:,:],np.nan),cmap=colormaps['prism'],norm=ID_norm,shading='nearest',transform=proj_PC)
# cax = plt.gcf().add_axes([0.05,cbar_fract*0.66,0.9,0.02])
# cb = plt.colorbar(mappable=cf,cax=cax,orientation='horizontal',ticks=range(1,n_radars+1),drawedges=True)
# cb.ax.tick_params(labelsize=6)
# cb.set_label(f"Integer key to radar illuminating this grid point at height {z} km",fontsize=8)
 plt.figtext(0.01,0.01,f"Height: {1e3*z:.0f} m",ha='left',va='bottom',fontsize=10,fontweight=500,bbox={'facecolor':'white','edgecolor':'black','pad':3})
 plt.savefig(f"radar_mask{mask_name}_ID_{z*1e3:05.0f}m.png",dpi=200)
 plt.close()
