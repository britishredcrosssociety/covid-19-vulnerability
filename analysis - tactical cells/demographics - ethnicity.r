##
## Demographic analyses: ethnicity
##
library(tidyverse)
library(nomisr)

source("analysis - tactical cells/create lookup table - neighbourhood to Tactical Cell.r")
tc_curr = "South and the Channel Islands"


##
## Census ethnicity data from table KS201EW: Ethnic Group
## https://www.nomisweb.co.uk/census/2011/ks201ew
##
# Nomis API URL: https://www.nomisweb.co.uk/api/v01/dataset/NM_608_1.jsonstat.json?date=latest&geography=&rural_urban=0,100,101&cell=0,100,1...4,200,5...8,300,9...13,400,14...16,500,17,18&measures=20301
census_raw = nomis_get_data(
  id = "NM_608_1",
  date = "latest",
  geography = "TYPE297",  # MSOA
  
  rural_urban = "0,100,101",  # total urban and total rural, plus overall total
  cell = "0,100,1...4,200,5...8,300,9...13,400,14...16,500,17,18",  # all ethnic group categories
  
  # measures = "20301",  # percentages
  measure = "20100",   # values
  
  
  # variables to keep
  select = c(
    "GEOGRAPHY_CODE",
    "MEASURES_NAME",
    "RURAL_URBAN_NAME",
    "CELL_NAME",
    "OBS_VALUE"
  )
)

# unique(census_raw$CELL_NAME)

census = census_raw %>% 
  filter(RURAL_URBAN_NAME == "Total") %>% 
  select(Code = GEOGRAPHY_CODE, Ethnicity = CELL_NAME, Value = OBS_VALUE) %>% 
  filter(Ethnicity %in% c("White", "Asian/Asian British", "Black/African/Caribbean/Black British", "Mixed/multiple ethnic groups", "Other ethnic group"))

census_detailed = census_raw %>% 
  filter(RURAL_URBAN_NAME == "Total") %>% 
  select(Code = GEOGRAPHY_CODE, Ethnicity = CELL_NAME, Value = OBS_VALUE) %>% 
  filter(!Ethnicity %in% c("All usual residents", "White", "Asian/Asian British", "Black/African/Caribbean/Black British", "Mixed/multiple ethnic groups", "Other ethnic group"))

##
## calculate UK-wide and Cell proportions
##
census_uk = census_detailed %>% 
  group_by(Ethnicity) %>% 
  summarise(Prop = sum(Value) / sum(census_detailed$Value))

# histogram of ethnicities within each the Cell
census_cell = census_detailed %>% 
  # get tactical cells
  left_join(msoa_lad_tc, by = c("Code" = "MSOA11CD")) %>% 
  filter(TacticalCell == tc_curr)

census_cell %>% 
  group_by(Ethnicity) %>% 
  summarise(Prop = sum(Value) / sum(census_cell$Value)) %>% 
  
  ggplot(aes(x = Ethnicity, y = Prop)) + 
  
  geom_col(fill = "cornflowerblue") +
  geom_point(data = census_uk, size = 1.5) +
  
  coord_flip() +
  
  scale_y_continuous(labels = scales::percent) +
  
  labs(x = NULL, y = "Percentage of people") +
  
  theme_light() +
  theme(panel.border        = element_blank()
        ,axis.text          = element_text(size = 8)
        ,legend.text        = element_text(size = 8)
        ,legend.title       = element_blank()
        ,legend.position    = "bottom"
        ,panel.grid.major.x = element_blank()
        ,panel.grid.minor.x = element_blank()
        ,plot.margin        = margin(0.5, 0, 0.2, 0, "cm")
        ,panel.grid.major   = element_blank()
        ,panel.grid.minor   = element_blank()
        ,panel.background   = element_rect(fill = "transparent", colour = NA)
        ,plot.background    = element_rect(fill = "transparent", colour = NA)
  )

ggsave(file.path("maps/tactical cells", tc_curr, "ethnicity.png"), bg = "transparent", width = 200, height = 85, units = "mm")
