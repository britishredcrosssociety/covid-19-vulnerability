##
## Digital exclusion in tactical cells
##
library(tidyverse)
library(readxl)
library(janitor)

source("functions.r")

data_dir = "C:/Users/040026704/Documents/Data science/Data/CACI"

##
## load data (that we can't share publicly)
##
# vulnerability indicators - deciles
vuln = read_csv(file.path(data_dir, "CCI_British Red Cross - UK Postcodes with Vunerability Indicators.csv"))
vuln_raw = read_csv(file.path(data_dir, "vul_zscores.csv"))

##
## load data (that can be shared publicly)
##
postcodes = read_csv("data/postcodes/Data/ONSPD_FEB_2020_UK.csv")
pc_tc = read_csv("data/lookup postcode prefix to tactical cell.csv")

# the ONS data truncates 7-character postcodes to remove spaces (e.g. CM99 1AB --> CM991AB); get rid of all spaces in both datasets to allow merging
# postcodes$Postcode2 = gsub(" ", "", postcodes$pcd)
# vuln$Postcode2 = gsub(" ", "", vuln$Postcode)

vuln$PostcodePrefix = str_sub(vuln$Postcode, 1, 2)

vuln = vuln %>% 
  left_join(pc_tc, by = c("PostcodePrefix" = "Postcode"))

# most vulnerable postcodes in South & Channel Islands
sci_vuln = vuln %>% 
  filter(Cell == "South and the Channel Islands" & `Digital_combined_-_Decile` == 1) %>% 
  select(Area, Postcode) %>% 
  arrange(Area, Postcode)

sci_vuln %>% write_csv("output/South and Channel Islands most digitall excluded postcodes.csv")

v2 = vuln_raw %>% filter(postcode == "BA 1 1ER")
