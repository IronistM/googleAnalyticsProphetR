# googleAnalyticsProphetR
Applying Facebook's prophet on Google Analytics data

# Motivation
One the problems we have in Digital Analytics is figuring out when something has stopped recording or fires more frequently that it should (you know ; fire once per page vs per event).

# Strategy
In this attempt we are taking a data-driven approach to detecting deviations from the "expected" (ref: remains to be defined). One of the most accesible ways to get a estimation of "expected" is by using Facebook's [prophet](https://github.com/facebook/prophet) API which is available both in R and Python. The proposed strategy is to create daily the prediction for the previous day and compare it to the actual count of events in discussion.

In practice, prophet does really well in point estimation but we can also get upper and lower prediction bounds. Actually, we will trigger an alert when the actual value is outside these bounds.

# Under the hood
To create the we have wrapped somethings around the following functions that are originating from [`googleAnalyticsR`](https://github.com/MarkEdmondson1234/googleAnalyticsR) and [`prophet`](https://github.com/facebook/prophet) :

- `get_ga_data()`
- `get_prophet_prediction()`
- `get_prophet_prediction_graph()`

*Side note* : Actually there is another function that is based on Twitter's awesome [`AnomalyDetection`](https://github.com/twitter/AnomalyDetection) package (only for R).

# Example(s)
There is a sample RNotebook under the Reports folder ([report.rmd](https://github.com/IronistM/googleAnalyticsProphetR/blob/master/Reports/report.rmd)) that you can use with minimal configuration.

## Configuration
### Packages
As usual you will need to have all the packages mentioned on the [requirements.R](https://github.com/IronistM/googleAnalyticsProphetR/blob/master/requirements.R) file.

### Authentication
Then you will need to authenticate to Google via any method you like and is provide in [googleAuthR](https://github.com/MarkEdmondson1234/googleAuthR), in the example I authenticate once and then reuse the `.httr-oauth`. A deeper explanation of authentication can be found [here](http://code.markedmondson.me/googleAuthR/articles/google-authentication-types.html).


I handle more of this using the following chunk of code.

```R
# Required packages
source("../requirements.R")

## Functions needed
source("../Functions/functions.R")

## Project settings
source("../Configuration/project_settings.R")

## Authentication with googleapis -----------------------------------
options(
  googleAuthR.scopes.selected =
    c(
      # "https://www.googleapis.com/auth/webmasters",
      "https://www.googleapis.com/auth/analytics",
      "https://www.googleapis.com/auth/analytics.readonly",
      "https://www.googleapis.com/auth/tagmanager.readonly"
      # "https://www.googleapis.com/auth/devstorage.full_control",
      # "https://www.googleapis.com/auth/cloud-platform",
      # "https://www.googleapis.com/auth/bigquery",
      # "https://www.googleapis.com/auth/bigquery.insertdata"
    )
)

googleAuthR::gar_auth(".httr-oauth")
```


### Parameters
You will need to pass your `GA_VIEW_ID` for the API calls and your dimensions and metric of interest (default :  `totalEvents`). Note, that since we need to have a time series by the definition of the problem `date` is always added in the dimensions.

```R
## Define the ID of the VIEW we need to fetch
id <- "YOUR_VIEW_ID" # this is for the internal/legacy/YOU_NAME_IT...

## Build the event list we are interested
## in monitoring for the V1.0
events_category <- c(
  # YOUR_EVENTS_LIST
)

## Dimensions for breakdown
dimensions <- c(
  # YOUR_DIMENSIONS_LIST
)
```

## Acquire the data
Now, we are pulling the data from Google Analytics API. We are pushing the `events_category` as a paremeter to the `get_ga_data` and getting a dataframe back using purrr's `map_df()` ; which is awesome.

```R
## Get the data from GA
ga_data <- events_category %>%
  map_df(~ get_ga_data(id, start, end, .x, breakdown_dimensions = dimensions))
```
Now, we can check what we got data via a summary of the `ga_data`. You can use base [`summary`](http://stat.ethz.ch/R-manual/R-devel/library/base/html/summary.html) or [`skimr`](https://github.com/ropenscilabs/skimr); I use the second one.

```R
# Summary of what we got from GA API
# Look for strange things in the 'n_unique' column of dimensions
# and 5-num summary of metrics (ie totalEvents)
ga_data %>%
  skimr::skim_to_wide()
```
|type      |variable                  |missing |complete |n    |min        |max        |empty |n_unique |median     |mean    |sd     |p25 |p75 |hist     |
|:---------|:-------------------------|:-------|:--------|:----|:----------|:----------|:-----|:--------|:----------|:-------|:------|:---|:---|:--------|
|character |channelGrouping           |0       |3000     |3000 |3          |13         |0     |11       |NA         |NA      |NA     |NA  |NA  |NA       |
|character |deviceCategory            |0       |3000     |3000 |6          |7          |0     |3        |NA         |NA      |NA     |NA  |NA  |NA       |
|character |eventAction               |0       |3000     |3000 |11         |19         |0     |4        |NA         |NA      |NA     |NA  |NA  |NA       |
|character |landingContentGroup1      |0       |3000     |3000 |4          |15         |0     |9        |NA         |NA      |NA     |NA  |NA  |NA       |
|character |sourcePropertyDisplayName |0       |3000     |3000 |33         |37         |0     |3        |NA         |NA      |NA     |NA  |NA  |NA       |
|Date      |date                      |0       |3000     |3000 |2017-07-01 |2017-07-15 |NA    |15       |2017-07-07 |NA      |NA     |NA  |NA  |NA       |
|numeric   |totalEvents               |0       |3000     |3000 |26         |39625      |NA    |NA       |181        |1460.48 |3921.3 |52  |645 |▇▁▁▁▁▁▁▁ |


### Interlude : The tricky part
You will need to do your own sanity check of inputs to the data that we pass to prophet object! This is out of the scope of the current implementation. So use the section below for passing over the constrains you'd like to, in other words create filters...

```R
data <- ga_data %>%
  filter(deviceCategory != "tablet")

## Let's keep the most important stuff
channel_groups <- c("Direct", "Non Brand SEO", "Brand SEO", "SEM Brand", "SEM Non Brand")
landing_groups <- c(
  # YOUR_LANDING_PAGE_GROUP_LIST
  )
```
## Get predictions

```R
## Apply the prophet prediction to each group
prophet_data <- data %>%
  filter(channelGrouping %in% channel_groups &
           landingContentGroup1 %in% landing_groups) %>%
  filter(sourcePropertyDisplayName == "DHH - Greece - Efood - Web - Live") %>%
  group_by_if(is.character) %>% # group by all dimensions present to `data`
  # filter(date > today() - days(60)) %>%
  arrange(date) %>% # order by date explicitly!
  nest() %>%
  mutate(n_rows = map_dbl(data, ~ suppressWarnings(
    length(.x[["date"]]))),
    last_date = map(data, ~ max(.x[["date"]]))) %>%
  filter(n_rows > 2) %>% 
  mutate(prophet_range = map_chr(data, ~ suppressWarnings(
    get_prophet_prediction(.x[["totalEvents"]], start_date = start,  daily.seasonality = TRUE)
  ))) %>%
  mutate(last_day = map_dbl(data, ~ last(.x[["totalEvents"]]))) %>% # this is the last day ; we'll compare against it
  separate(prophet_range,
           into = c("min", "estimate", "max"),
           sep = ",") %>%
  mutate(
    prophet_lower_range = as.numeric(min),
    prophet_estimate_point = as.numeric(estimate),
    prophet_upper_range = as.numeric(max)
  )
```
## Inspect predictions
Let's check a random 10 rows of prediction along their actual value on the last day of the run.

```R
prophet_data %>%
  dplyr::select(-min, -max, -estimate, -data) %>%
  mutate_at(vars(starts_with("prophet_")), funs(round(., digits = 2))) %>%
  filter(prophet_lower_range > 0) %>% 
  dplyr::select(-prophet_lower_range, -prophet_upper_range) %>%
  sample_n(10)
```

|eventAction         |sourcePropertyDisplayName         |channelGrouping |deviceCategory |landingContentGroup1 | n_rows|last_date | last_day| prophet_estimate_point|
|:-------------------|:---------------------------------|:---------------|:--------------|:--------------------|------:|:---------|--------:|----------------------:|
|engagement         |Blog - Live |Direct          |desktop        |post_list            |      9|17550     |        1|                   1.00|
|post_list.loaded    |Blog - Live |SEM Brand       |mobile         |post         |     82|17552     |      609|                 375.29|
|post.loaded |Blog - Live |SEM Non Brand   |mobile         |home                 |     82|17552     |     2320|                1553.62|
|engagement         |Blog - Live |SEM Non Brand   |desktop        |post         |     82|17552     |      382|                 318.80|
|post_list.loaded    |Blog - Live |Direct          |desktop        |home                 |     82|17552     |     7451|                6500.48|
|post.loaded |Blog - Live |Non Brand SEO   |desktop        |post_list            |     82|17552     |     6045|                4957.95|
|post.loaded |Blog - Live |Non Brand SEO   |mobile         |(not set)            |     82|17552     |       95|                  60.29|
|engagement         |Blog - Live |SEM Brand       |mobile         |home                 |     82|17552     |     5185|                3723.87|
|post.loaded |Blog - Live |Direct          |mobile         |home                 |     82|17552     |     1828|                1179.51|
|engagement         |Blog - Live |Non Brand SEO   |mobile         |post         |     82|17552     |      281|                 221.15|


## Get Alert
Next, we pull all the deviating cases.    
(*NOTE* : If this section is empty then we have no anomalous case)

```R
## Apply the prophet prediction to each group
alert_data <- prophet_data %>%
  rowwise() %>%
  filter(prophet_lower_range > 0) %>%
  mutate(flag = if_else(
    between(last_day, prophet_lower_range, prophet_upper_range),
    0,
    1
  )) %>%
  filter(flag > 0) %>%
  dplyr::select(-min, -max, -estimate, -data) %>%
  mutate_at(vars(starts_with("prophet_")), funs(round(., digits = 2)))
```
# Extension(s)
Now, you can push the above into Slack (using [`Slackr`](https://github.com/hrbrmstr/slackr)) or send an email (using [`blastula`](https://github.com/rich-iannone/blastula) for example).
