## This is our requirements R script
require(googleAnalyticsR)
require(lubridate)
require(magrittr)
require(AnomalyDetection)
require(hrbrthemes)
require(ggplot2)
require(plyr)
require(dplyr) # need to load plyr before dplyr & not the other way!
require(tidyr)
require(stringr)
require(janitor)
require(purrr)

## TODO : This would better if everything was in CRAN
# packages_reqs <- c("googleAnalyticsR","lubridate",
#                    "dataframes2xls","ggthemr","plyr",
#                    "dplyr","tidyr","stringr","janitor")
# UsePackage(packages_reqs)