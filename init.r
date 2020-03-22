data.dir = "./data"
data.dir.in = file.path(data.dir, "raw")
data.dir.processed = file.path(data.dir, "processed")
data.dir.out = "./output"

# map_proj = CRS("+init=epsg:27700")
map_proj = sp::CRS("+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0")  # use this projection for all boundaries

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

# create directories
if (!dir.exists(data.dir.processed)) dir.create(data.dir.processed)
if (!dir.exists(data.dir.out)) dir.create(data.dir.out)
