import numpy as np
import pandas as pd
from math import radians, cos, sin, acos, sqrt
from geopy import distance

# SETTINGS
US_radar_file = "/work/noaa/wrfruc/jdduda/RadarNext/nexrad-stations-valid-2026.txt"
set_ = "A"

maj_axis = distance.ELLIPSOIDS['WGS-84'][1]
min_axis = distance.ELLIPSOIDS['WGS-84'][0]
Re = sqrt(maj_axis * min_axis) * 1000.0

def gc_matrix(lons, lats):
    """Vectorized Great-Circle distance matrix (meters)."""
    lons, lats = np.radians(lons), np.radians(lats)
    
    cos_lat = np.cos(lats)
    sin_lat = np.sin(lats)
    
    # Cosine law vectorized over grid mesh
    dlon = lons[:, None] - lons[None, :]
    cos_g = sin_lat[:, None] * sin_lat[None, :] + cos_lat[:, None] * cos_lat[None, :] * np.cos(dlon)
    cos_g = np.clip(cos_g, -1.0, 1.0)
    
    dist = Re * np.arccos(cos_g)
    np.fill_diagonal(dist, np.inf)  # Ignore self-distance
    return dist

# Load radar dataset
df = pd.read_table(US_radar_file, sep=r"\s+", header=0, skiprows=[1], index_col='ICAO')
print(df)

radar_codes = df.index.to_numpy()
radar_names = df['NAME']#   .to_numpy()
lons = df['LON'].to_numpy(dtype=float)
lats = df['LAT'].to_numpy(dtype=float)

n_radars = len(radar_codes)
dist_matrix = gc_matrix(lons, lats)

# Baseline metrics
nn_dist = np.min(dist_matrix, axis=1)
nn_idx = np.argmin(dist_matrix, axis=1)

print(f"Average baseline nearest radar distance: {np.mean(nn_dist)/1e3:.1f} km")

# Perform spatial thinning for various removal fractions
#removal_fractions = [0.1, 0.2, 0.3]
removal_fractions = [0.5]

for f in removal_fractions:
    num_to_remove = int(f * n_radars)
    n_remaining_radars = n_radars - num_to_remove
    # Maintain active masks and current distance matrix
    active_mask = np.ones(n_radars, dtype=bool)
    curr_dist_matrix = dist_matrix.copy()
    removed_codes = []

    for step in range(num_to_remove):
        # 1. Identify current nearest neighbor index and distance for each active radar
        nn_indices = np.argmin(curr_dist_matrix, axis=1)
        nn_distances = np.min(curr_dist_matrix, axis=1)

        # 2. Find the global minimum distance among remaining radars
        min_dist_idx = np.argmin(nn_distances)
        target_a = min_dist_idx
        target_b = nn_indices[target_a]

        # 3. Check if target_a and target_b are mutual nearest neighbors
        is_mutual = (nn_indices[target_b] == target_a)

        # Select target_a to remove (if mutual, target_a is dropped while target_b stays)
        # Switch below line between target_a and target_b for complementary networks
        if set_ == "A":
           radar_to_remove_idx = target_a
        elif set_ == "B":
           radar_to_remove_idx = target_b
        removed_code = radar_codes[radar_to_remove_idx]
        removed_codes.append(removed_code)

        # 4. Deactivate station by setting its distances to infinity
        curr_dist_matrix[radar_to_remove_idx, :] = np.inf
        curr_dist_matrix[:, radar_to_remove_idx] = np.inf
        active_mask[radar_to_remove_idx] = False

        print(f"[{step+1}/{num_to_remove}] Removed {removed_code} "
              f"(Nearest neighbor: {radar_codes[target_b]}, Dist: {nn_distances[target_a]/1e3:.1f} km, Mutual: {is_mutual})")

    remaining_codes = radar_codes[active_mask]
    print(f"Thinning {int(f*100)}% complete. Remaining radars: {len(remaining_codes)}\n")

    print("The list of removed radars:")
    print(removed_codes)

    print("The remaining radars:")
    print(remaining_codes)

    # Get the original indices of the active radars
    original_indices = np.where(active_mask)[0]
    # Print side-by-side: Original Index -> Radar Code
    for idx, code in zip(original_indices, remaining_codes):
       print(f"Original Index {idx:3d} : {code}")

    f1 = open(f"US_radar_nearest_neighbor_alphabetical_lost{int(f*100):d}_{set_}.txt",'w')
    for idx, code in zip(original_indices, remaining_codes):
#      print(f"Original Index {idx:3d} : {code}")
      f1.writelines(f"{code:5s} {radar_names[idx]:30s}: {np.min(curr_dist_matrix,axis=1)[idx]/1e3:5.1f} km\n")
    f1.close()
    f3 = open(f"US_radars_slimmed_closest_{100*f:.0f}_pct_{set_}.txt",'w')
    f3.writelines("NCDCID   ICAO WBAN  NAME                           COUNTRY              ST COUNTY                         LAT       LON        ELEV   UTC   BAND\n")
    f3.writelines("-------- ---- ----- ------------------------------ -------------------- -- ------------------------------ --------- ---------- ------ ----- ---------\n")
    for i in range(n_remaining_radars):
      name = remaining_codes[i]
      NCDCID = df['NCDCID'].loc[name]
      ICAO = name
      WBAN = df['WBAN'].loc[name]
      NAME = df['NAME'].loc[name]
      COUNTRY = "UNITED_STATES"
      ST = df['ST'].loc[name]
      COUNTY = df['COUNTY'].loc[name]
      LAT = df['LAT'].loc[name]
      LON = df['LON'].loc[name]
      ELEV = df['ELEV'].loc[name]
      UTC = df['UTC'].loc[name]
      BAND = df['BAND'].loc[name]
      f3.writelines(f"{NCDCID} {ICAO} {WBAN:5d} {NAME:30s} {COUNTRY:20s} {ST} {COUNTY:30s} {LAT:<9.5f} {LON:<10.5f} {ELEV:6.0f} {UTC:5d} {BAND}\n")
    f3.close()
