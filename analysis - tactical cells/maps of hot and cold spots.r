##
## Maps of hot and cold spots for each category of need within each Tactical Cell
## - food: access to supermarkets and food shops
## - health/wellbeing vulnerability
## - clinical vulnerability
## - economic vulnerability
## - digital exclusion
## - people seeking asylum
##
## Hot spots = 20% most vulnerable
## Cold spots = 20% least vulnerable
##
## Maps should show:
## - Tactical Cell boundaries
## - Local Authorities
## - vunerable MSOAs
##
library(tidyverse)
library(sf)
library(tmap)

source("load lookup tables.r")
source("https://github.com/matthewgthomas/brclib/raw/master/R/colours.R")  # for get_brc_colours()

brc_cols = get_brc_colours()


##
## Load boundaries
##
tc = read_sf("data/boundaries/Tactical_cells.shp") %>% 
  st_transform(crs = 27700)

# Local Authority Districts (December 2019) Boundaries UK BUC
# source: https://geoportal.statistics.gov.uk/datasets/local-authority-districts-december-2019-boundaries-uk-buc
lads = read_sf("https://opendata.arcgis.com/datasets/3a4fa2ce68f642e399b4de07643eeed3_0.geojson") %>% 
  st_transform(crs = 27700)

# lookup which Tactical Cells each LA is in
lads_tc = lads %>% 
  st_centroid() %>% 
  st_join(tc) %>% 
  st_drop_geometry() %>% 
  select(lad19cd, name)

lads = lads %>% 
  left_join(lads_tc, by = "lad19cd")

lads = lads %>% 
  mutate(name = case_when(
    str_sub(lad19cd, 1, 1) == "W" ~ "Wales",
    str_sub(lad19cd, 1, 1) == "S" ~ "Scotland",
    str_sub(lad19cd, 1, 1) == "N" ~ "Northern Ireland",
    TRUE ~ name
  ))

# Major Towns and Cities (December 2015) Boundaries
# source: https://geoportal.statistics.gov.uk/datasets/major-towns-and-cities-december-2015-boundaries
# towns = read_sf("https://opendata.arcgis.com/datasets/58b0dfa605d5459b80bf08082999b27c_0.geojson") %>% 
#   st_transform(crs = 27700)
# 
# # lookup which Tactical Cells each LA is in
# towns_tc = towns %>% 
#   st_centroid() %>% 
#   st_join(tc) %>% 
#   st_drop_geometry() %>% 
#   select(tcity15cd, name)
# 
# towns = towns %>% 
#   left_join(towns_tc, by = "tcity15cd")


##
## make MSOA to LA to Tactical Cell lookup
##
msoa_lad = load_lookup_lsoa_msoa_lad() %>% 
  select(MSOA11CD, LAD17CD) %>% 
  distinct()

lad_17_19 = read_csv("data/LAD 2017 to LAD 2019 codes.csv")

lad_tc = read_csv("data/lookup local authority to tactical cell.csv")

msoa_lad_tc = msoa_lad %>% 
  left_join(lad_17_19, by = "LAD17CD") %>% 
  left_join(lad_tc, by = "LAD19CD")


##
## vulnerability index
##
vi = read_sf("output/vulnerability-MSOA-UK.geojson")
vi_food = read_sf("bespoke vulnerability index - food/food-vulnerability-MSOA-England.geojson")
# digital = read_csv("data/CACI/digital-exclusion-msoa.csv")
asylum = read_csv("data/asylum-LA.csv")

# load digital exclusion
caci_vuln_lsoa = read_csv("data/CACI/digital-exclusion-lsoa.csv")
caci_vuln_msoa = read_csv("data/CACI/digital-exclusion-msoa.csv")
# merge SOAs for Northern Ireland into the MSOA dataframe
digital = caci_vuln_msoa %>% 
  filter(!startsWith(MSOA11CD, "N")) %>%  # no MSOAs in Northern Ireland
  
  bind_rows( caci_vuln_lsoa %>% filter(startsWith(LSOA11CD, "9")) %>% rename(MSOA11CD = LSOA11CD) ) %>% 
  
  select(MSOA11CD, `Digital Vulnerability score`)

rm(caci_vuln_lsoa, caci_vuln_msoa)

vi = vi %>% left_join(msoa_lad_tc, by = c("Code" = "MSOA11CD"))
vi_food = vi_food %>% left_join(msoa_lad_tc, by = c("Code" = "MSOA11CD"))
digital = digital %>% left_join(msoa_lad_tc, by = "MSOA11CD")
asylum = asylum %>% left_join(lad_tc, by = "LAD19CD")

# manually point out if Northern Ireland cell
vi = vi %>% mutate(TacticalCell = ifelse(str_sub(Code, 1, 1) == "9", "Northern Ireland", TacticalCell))
vi_food = vi_food %>% mutate(TacticalCell = ifelse(str_sub(Code, 1, 1) == "9", "Northern Ireland", TacticalCell))
digital = digital %>% mutate(TacticalCell = ifelse(str_sub(MSOA11CD, 1, 1) == "9", "Northern Ireland", TacticalCell))
asylum = asylum %>% mutate(TacticalCell = ifelse(str_sub(LAD19CD, 1, 1) == "N", "Northern Ireland", TacticalCell))

# add digital exclusion to boundaries
# Middle Layer Super Output Areas (December 2011) Boundaries EW BSC
# source: https://geoportal.statistics.gov.uk/datasets/middle-layer-super-output-areas-december-2011-boundaries-ew-bsc
msoa = read_sf("https://opendata.arcgis.com/datasets/c661a8377e2647b0bae68c4911df868b_3.geojson") %>%
  st_transform(crs = 27700)

digital = msoa %>% 
  left_join(digital, by = c("msoa11cd" = "MSOA11CD")) %>% 
  select(Code = msoa11cd, everything(), -objectid, -msoa11nm, -msoa11nmw, -st_areashape, -st_lengthshape)


##
## loop over Tactical Cells, creating maps for each
##
# helper function to mark 20% most vulnerable and 20% least vulnerable
hotcold = function(x) case_when(
  x <= 2 ~ "Least vulnerable",
  x >= 9 ~ "Most vulnerable",
  TRUE ~ ""
)

for (tc_curr in unique(tc$name)) {
  # tc_curr = "South and the Channel Islands"
  # tc_curr = "Northern Ireland"
  
  # get subsets of boundaries within current Cell
  lads_s = lads %>% filter(name == tc_curr)
  # tc_s = tc %>% filter(name == tc_curr)
  # towns_s = towns %>% filter(name == tc_curr)
  
  # get vulnerability scores within this Cell
  digital_s = digital %>% 
    filter(TacticalCell == tc_curr) %>% 
    mutate(HotCold = hotcold(`Digital Vulnerability decile`)) %>% 
    filter(HotCold != "")
  
  vi_s_economic = vi %>% 
    filter(TacticalCell == tc_curr) %>% 
    mutate(HotCold = hotcold(Economic.Vulnerability.decile)) %>% 
    filter(HotCold != "")
  
  vi_s_health = vi %>% 
    filter(TacticalCell == tc_curr) %>% 
    mutate(HotCold = hotcold(Health.Wellbeing.Vulnerability.decile)) %>% 
    filter(HotCold != "")
  
  vi_s_clinical = vi %>% 
    filter(TacticalCell == tc_curr) %>% 
    mutate(HotCold = hotcold(Clinical.Vulnerability.decile)) %>% 
    filter(HotCold != "")
  
  vi_s_food = vi_food %>% 
    filter(TacticalCell == tc_curr) %>% 
    mutate(HotCold = hotcold(Food.Vulnerability.decile)) %>% 
    filter(HotCold != "")
  
  asylum_s = lads_s %>% 
    left_join(asylum, by = c("lad19cd" = "LAD19CD")) %>% 
    mutate(HotCold = case_when(
      Sec95_q == 1 ~ "Fewest/no asylum seekers",
      Sec95_q == 5 ~ "Most asylum seekers",
      TRUE ~ ""
    )) %>% 
    filter(HotCold != "")
  
  # asylum %>% 
  #   filter(TacticalCell == tc_curr) %>% 
  #   summarise(n = sum(`People receiving Section 95 support`))
  
  
  ##
  ## make hot/cold spot maps
  ##
  # basemap showing tactical cell and local authorities
  basemap = tm_shape(lads_s) +
    tm_polygons(col = "white", border.alpha = 0.5)
  
   # tm_shape(tc_s) +
   # tm_polygons(col = "white", border.alpha = 0.8) 
  
  # digital exclusion
  map_digital = basemap +
    tm_shape(digital_s) +
    tm_polygons(col = "HotCold", palette = c(brc_cols$teal_light, brc_cols$red), border.alpha = 0, title = "Digital exclusion")
  
  # clinical vulnerability
  map_clinical = basemap +
    tm_shape(vi_s_clinical) +
    tm_polygons(col = "HotCold", palette = c(brc_cols$teal_light, brc_cols$red), border.alpha = 0, title = "Clinical vulnerability")
  
  # economic vulnerability
  map_economic = basemap +
    tm_shape(vi_s_economic) +
    tm_polygons(col = "HotCold", palette = c(brc_cols$teal_light, brc_cols$red), border.alpha = 0, title = "Economic/financial vulnerability")
  
  # health/wellbeing vulnerability
  map_health = basemap +
      tm_shape(vi_s_health) +
      tm_polygons(col = "HotCold", palette = c(brc_cols$teal_light, brc_cols$red), border.alpha = 0, title = "Health/wellbeing vulnerability")
  
  # food vulnerability
  map_food = basemap +
      tm_shape(vi_s_food) +
      tm_polygons(col = "HotCold", palette = c(brc_cols$teal_light, brc_cols$red), border.alpha = 0, title = "Food insecurity")
  
  # asylum support
  map_asylum = basemap +
    tm_shape(asylum_s) +
    tm_polygons(col = "HotCold", palette = c(brc_cols$teal_light, brc_cols$red), border.alpha = 0.5, title = "Asylum seekers receiving Government support")
  
  # save maps
  if (!dir.exists(file.path("maps/tactical cells", tc_curr))) dir.create(file.path("maps/tactical cells", tc_curr))  # create folder for this Cell if needed
  
  tmap_save(map_digital,  file.path("maps/tactical cells", tc_curr, "digital.png"))
  tmap_save(map_clinical, file.path("maps/tactical cells", tc_curr, "clinical.png"))
  tmap_save(map_economic, file.path("maps/tactical cells", tc_curr, "economic.png"))
  tmap_save(map_health,   file.path("maps/tactical cells", tc_curr, "health.png"))
  tmap_save(map_food,     file.path("maps/tactical cells", tc_curr, "food.png"))
  tmap_save(map_asylum,   file.path("maps/tactical cells", tc_curr, "asylum.png"))
  
  print(paste0("Finished ", tc_curr))

}  # end for loop
