import xarray as xr
import xregrid
import numpy as np
from timeit import default_timer

file_name = "/work2/noaa/wrfruc/murdzek/geogrid_no_smooth/single_file/geo_em.d01.nc"
ds = xr.open_dataset(file_name,engine='netcdf4')

ds2 = ds.rename({'XLAT_M':'lat','XLONG_M':'lon'})

terrain = ds['HGT_M']
landmask = ds['LANDMASK']
union_ds = xr.merge([terrain,landmask])

new_grid = xr.Dataset({
    'lat': (["lat"], np.arange(20.005,54.996,0.01)),
    'lon': (["lon"], np.arange(230.005,299.996,0.01)),
     })

time1 = default_timer()
regridder = xregrid.Regridder(ds2,new_grid,method='nearest_s2d')
time2 = default_timer()
regrid_terrain = regridder(union_ds)
time3 = default_timer()

print(f"Time to create regridder instance: {time2-time1:.1f} s")
print(f"Time to perform regridding: {time3-time2:.1f} s")
regrid_terrain.to_netcdf("NR_to_MRMS_grid.nc",'w','NETCDF4',engine='netcdf4')
