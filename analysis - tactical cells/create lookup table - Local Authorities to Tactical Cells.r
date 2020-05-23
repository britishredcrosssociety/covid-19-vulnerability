##
## create lookup table from LAs to Tactical Cells (England only - there's only one Cell per devolved nation)
##
library(tidyverse)
library(sf)

tc = read_sf("data/boundaries/Tactical_cells.shp") %>% 
  st_transform(crs = 27700)

# Local Authority Districts (December 2019) Boundaries UK BUC
# source: https://geoportal.statistics.gov.uk/datasets/local-authority-districts-december-2019-boundaries-uk-buc
lads = read_sf("https://opendata.arcgis.com/datasets/3a4fa2ce68f642e399b4de07643eeed3_0.geojson")

lad_cents = lads %>% 
  st_transform(crs = 27700) %>% 
  st_centroid()

lad_tc = lad_cents %>% 
  st_join(tc) %>% 
  st_drop_geometry() %>% 
  select(LAD19CD = lad19cd, TacticalCell = name) %>% 
  
  # mark TCs for devolved nations
  mutate(TacticalCell = case_when(
    startsWith(LAD19CD, "W") ~ "Wales",
    startsWith(LAD19CD, "S") ~ "Scotland",
    startsWith(LAD19CD, "N") ~ "Northern Ireland and Isle of Man",
    LAD19CD == "E06000053" ~ "South and the Channel Islands",  # this centroid doesn't fall on the TC map
    TRUE ~ TacticalCell
  )) 
  
write_csv(lad_tc, "data/lookup local authority to tactical cell.csv")  
