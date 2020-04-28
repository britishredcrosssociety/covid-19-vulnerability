##
## Functions to load geographical lookup tables
##

#' Download names and codes of Local Authority Districts in the UK
#' 
#' @param url year 2017, 2018 or 2019
load_lads = function(year = 2017) {
  if (year == 2017)  # December 2017: https://geoportal.statistics.gov.uk/datasets/local-authority-districts-december-2017-names-and-codes-in-the-united-kingdom
    readr::read_csv("https://opendata.arcgis.com/datasets/a267b55f601a4319a9955b0197e3cb81_0.csv")
  
  else if (year == 2018)  # December 2018: https://geoportal.statistics.gov.uk/datasets/local-authority-districts-december-2018-names-and-codes-in-the-united-kingdom
    readr::read_csv("https://opendata.arcgis.com/datasets/17eb563791b648f9a7025ca408bb09c6_0.csv")
  
  else if (year == 2019)  # December 2019: https://geoportal.statistics.gov.uk/datasets/local-authority-districts-december-2019-names-and-codes-in-the-united-kingdom
    readr::read_csv("https://opendata.arcgis.com/datasets/35de30c6778b463a8305939216656132_0.csv")
  
}

##
## England and Wales
##
# Lower Layer Super Output Area (2011) to Ward (2019) Lookup in England and Wales
# source: https://geoportal.statistics.gov.uk/datasets/lower-layer-super-output-area-2011-to-ward-2019-lookup-in-england-and-wales
load_lookup_lsoa_ward = function(year = 2019) {
  if (year == 2019)
    url = "https://opendata.arcgis.com/datasets/15299a7b8e6c498d94a08b687c75b73f_0.csv"
  else if (year == 2017)
    url = "https://opendata.arcgis.com/datasets/500d4283cbe54e3fa7f358399ba3783e_0.csv"

  readr::read_csv(url) %>% 
    dplyr::select(dplyr::starts_with("LSOA"), dplyr::starts_with("WD"))
}

# Middle Layer Super Output Area (2011) to Ward (2017/19) Lookup in England and Wales
# source: https://geoportal.statistics.gov.uk/datasets/middle-layer-super-output-area-2011-to-ward-2017-lookup-in-england-and-wales and https://geoportal.statistics.gov.uk/datasets/middle-layer-super-output-area-2011-to-ward-to-lad-december-2019-lookup-in-england-and-wales
load_lookup_msoa_ward = function(year = 2019) {
  if (year == 2019)
    url = "https://opendata.arcgis.com/datasets/0b3c76d1eb5e4ffd98a3679ab8dea605_0.csv"
  else if (year == 2017)
    url = "https://opendata.arcgis.com/datasets/fcb3d6b3dc834e3ca3b38756b8b023f2_0.csv"
  
  readr::read_csv(url) %>% 
    dplyr::select(dplyr::starts_with("MSOA"), dplyr::starts_with("WD"))
}

# Output Area to LSOA to MSOA to Local Authority District (December 2017) Lookup with Area Classifications in Great Britain
# source: http://geoportal.statistics.gov.uk/datasets/fe6c55f0924b4734adf1cf7104a0173e_0
load_lookup_lsoa_msoa_lad = function(url = "https://opendata.arcgis.com/datasets/fe6c55f0924b4734adf1cf7104a0173e_0.csv") {
  readr::read_csv(url) %>% 
    dplyr::select(dplyr::starts_with("LSOA"), dplyr::starts_with("MSOA"), dplyr::starts_with("LAD")) %>% 
    dplyr::distinct()
}

# Local Authority District to Fire and Rescue Authority (December 2017) Lookup in England and Wales
# source: https://geoportal.statistics.gov.uk/datasets/local-authority-district-to-fire-and-rescue-authority-december-2017-lookup-in-england-and-wales-
load_lookup_lad_fra = function(url = "https://opendata.arcgis.com/datasets/fcd35bcc7cf64b68abb53a0097105914_0.csv") readr::read_csv(url)

##
## Scotland
##
# Look-up: Data zone to intermediate zone, local authority, health board, multi-member ward, Scottish parliamentary constituency 
# source: https://www.gov.scot/publications/scottish-index-of-multiple-deprivation-2020-data-zone-look-up/
load_lookup_dz_iz_lad = function(url = "https://www.gov.scot/binaries/content/documents/govscot/publications/statistics/2020/01/scottish-index-of-multiple-deprivation-2020-data-zone-look-up-file/documents/scottish-index-of-multiple-deprivation-data-zone-look-up/scottish-index-of-multiple-deprivation-data-zone-look-up/govscot%3Adocument/SIMD_2020_Datazone_lookup_tool.xlsx", 
                                 sheet_name = "SIMD 2020v2 DZ lookup data") {
  httr::GET(url, httr::write_disk(tf <- tempfile(fileext = ".xlsx")))
  
  readxl::read_excel(tf, sheet = sheet_name) %>% 
    dplyr::select(LSOA11CD = DZ, LSOA11NM = DZname, MSOA11CD = IZcode, MSOA11NM = IZname, WD17CD = MMWcode, LAD19CD = LAcode, LAD19NM = LAname) %>% 
    dplyr::distinct()
}

# Intermediate Zone 2011 Lookups
# source: https://www2.gov.scot/Topics/Statistics/sns/SNSRef/DZ2011Lookups
load_lookup_iz_ward = function(url = "https://www2.gov.scot/Resource/0046/00462938.csv") {
  readr::read_csv(url) %>% 
    select(MSOA11CD = InterZone, WD17CD = MMWard)
}

##
## Northern Ireland
##
# Small Areas (2011) to SOAs to Local Government Districts (December 2018) Lookup with Area Classifications in Northern Ireland
# source: https://geoportal.statistics.gov.uk/datasets/small-areas-2011-to-soas-to-local-government-districts-december-2018-lookup-with-area-classifications-in-northern-ireland
load_lookup_sa_lgd = function(url = "https://opendata.arcgis.com/datasets/096a7ccbc8e244cc972189b2f07a321a_0.csv") read_csv(url)

##
## function to look up country name from LSOA/MSOA/LAD/FRA code
##
get_country = function(code) {
  case_when(
    str_sub(code, 1, 1) == "E" ~ "England",
    str_sub(code, 1, 1) == "W" ~ "Wales",
    str_sub(code, 1, 1) == "S" ~ "Scotland",
    str_sub(code, 1, 1) %in% c("N", "9") ~ "Northern Ireland",
    TRUE ~ ""
  )
}