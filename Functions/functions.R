## Check and install package availability --------------------------------
InstalledPackage <- function(package)
{
  available <-
    suppressMessages(suppressWarnings(
      sapply(
        package,
        require,
        quietly = TRUE,
        character.only = TRUE,
        warn.conflicts = FALSE
      )
    ))
  missing <- package[!available]
  if (length(missing) > 0)
    return(FALSE)
  return(TRUE)
}

CRANChoosen <- function()
{
  return(getOption("repos")["CRAN"] != "@CRAN@")
}

UsePackage <-
  function(package, defaultCRANmirror = "http://cran.at.r-project.org")
  {
    if (!InstalledPackage(package))
    {
      if (!CRANChoosen())
      {
        chooseCRANmirror()
        if (!CRANChoosen())
        {
          options(repos = c(CRAN = defaultCRANmirror))
        }
      }
      
      suppressMessages(suppressWarnings(install.packages(package)))
      if (!InstalledPackage(package))
        return(FALSE)
    }
    return(TRUE)
  }

## Function to get data for one page out of Google Analytics ----------
get_ga_data <-
  function(id,
           startdate,
           enddate,
           eventName,
           breakdown_dimensions = NULL, ...) {
    # Create a string concat of extra dimensions
    if (!is.null(breakdown_dimensions)) {
      dims <- paste(breakdown_dimensions,
                    collapse = ", ",
                    sep = ", ")
    } else {
      dims <- NULL
    }
    # googleAuthR::gar_auth(".httr-oauth")
    # Create a dataframe
    df <- googleAnalyticsR::google_analytics_4(
      viewId = id,
      date_range = c(startdate, enddate),
      # start = startdate,
      # end = enddate,
      metrics = c("totalEvents"),
      dimensions = c("date", "eventAction", breakdown_dimensions),
      filtersExpression = paste("ga:eventAction=~", eventName, sep = ""), 
      anti_sample = TRUE,
      samplingLevel = "LARGE", 
      ...
    )
    # colnames(df) <- c('date', 'eventName', 'counts')
    return(df)
  }

## A function to get next day's prediction ------------------------
## NOTE : When using namespace call (ie prophet::xxxxx)
##  there is a jnow problem with cpp
##  https://github.com/facebook/prophet/issues/285
get_prophet_prediction <-
  function(series = NULL,
           start_date = NULL,
           ...) {
    # Print a nice message if prophet is missing
    if (!requireNamespace("prophet", quietly = TRUE)) {
      stop(
        "prophet needed for this function to work.
        Please install it via install.packages('prophet')",
        call. = FALSE
      )
    }
    else
      
    {
      library("prophet")
    }
    
    ## Holidays events
    newyear <- data_frame(
      holiday = 'newyear',
      ds = as.Date(c('2015-01-01', '2016-01-01', '2017-01-01','2018-01-01')),
      lower_window = 0,
      upper_window = 7
    )
    christmas <- data_frame(
      holiday = 'christmas',
      ds = as.Date(c('2015-12-25', '2016-12-25', '2017-12-25','2018-12-25')),
      lower_window = -2,
      upper_window = 7
    )
    easter <- data_frame(
      holiday = 'easter',
      ds = as.Date(c('2015-04-12', '2016-05-01', '2017-04-16', '2018-04-08')),
      lower_window = -7,
      upper_window = 6
    )
 
    # Create the holidays dataframe
    holidays <- bind_rows(newyear, christmas, easter)
    
    # Create a history placeholder
    history <- data.frame(ds = seq.Date(
      from = as.Date(start_date),
      by = "day",
      length.out = length(series)
    ),
    y = series)
    # Apply prophet on history
    m <- prophet::prophet(history, holidays = holidays, interval.width = 1)
    # Predict on last day
    future <- prophet::make_future_dataframe(m, periods = 1)
    forecast <- predict(m, future) %>% head(nrow(.)-1) 
    
    # Create a list of lower, upper and point forecast
    str_c(c(forecast$yhat_lower, forecast$yhat, forecast$yhat_upper),
          collapse = ",")
  }

## We need to create a safe version of the 'get_prophet_prediction' ----------------------------------------
## to not block the iterative apply on the dataframe
get_prophet_prediction_safe <-
  purrr::safely(get_prophet_prediction, otherwise = "0,0,0", quiet = TRUE)

## Graph the prediction
get_prophet_prediction_graph <-
  function(series = NULL,
           start_date = NULL,
           ...) {
    # Print a nice message if prophet is missing
    if (!requireNamespace("prophet", quietly = TRUE)) {
      stop(
        "prophet needed for this function to work.
        Please install it via install.packages('prophet')",
        call. = FALSE
      )
    }
    else
    {
      library("prophet")
    }
    ## Holidays events
    newyear <- data_frame(
      holiday = 'newyear',
      ds = as.Date(c('2015-01-01', '2016-01-01', '2017-01-01','2018-01-01')),
      lower_window = 0,
      upper_window = 7
    )
    christmas <- data_frame(
      holiday = 'christmas',
      ds = as.Date(c('2015-12-25', '2016-12-25', '2017-12-25','2018-12-25')),
      lower_window = -2,
      upper_window = 7
    )
    easter <- data_frame(
      holiday = 'easter',
      ds = as.Date(c('2015-04-12', '2016-05-01', '2017-04-16', '2018-04-08')),
      lower_window = -7,
      upper_window = 6
    )
    
    # Create the holidays dataframe
    holidays <- bind_rows(newyear, christmas, easter)
    
    # Create a history placeholder
    history <- data.frame(ds = seq.Date(
      from = as.Date(start_date),
      by = "day",
      length.out = length(series)
    ),
    y = series)
    # Apply prophet on history
    m <- prophet::prophet(history, holidays = holidays, interval.width = 1)
    # Predict on last day
    future <- prophet::make_future_dataframe(m, periods = 5)
    forecast <- predict(m, future) %>% 
      head(nrow(.)-1)
    
    # Create a list of lower, upper and point forecast
    plot(m, forecast) +
      geom_line() +
      hrbrthemes::scale_color_ipsum() +
      # labs(title = "How deep into the list?",
      #      subtitle = "Breakdown on filtered or no list & user type") +
      ggplot2::ylab("# Events") +
      ggplot2::xlab("Date") +
      hrbrthemes::theme_ipsum_rc(grid = "X") +
      ggplot2::theme(
        axis.text.y = element_text(size = 15),
        axis.text.x = element_text(size = 15),
        legend.position = "bottom",
        legend.text = element_text(size = 0)
      )
  }


## A function to perform Anomaly Detection
## This is based on Twitter's package
## 
check_anomaly <- function(...,
                          date = NULL,
                          counts = NULL,
                          title = NULL,
                          anoms = 0.02,
                          direction = direction,
                          piecewise_median_period_wk = NULL,
                          y_log = y_log,
                          longterm = NULL) {
  data <- data.frame(date, counts)
  
  # Need to make date  a POSIXct!
  data$date <- as.POSIXct(data$date)
  
  #Let's rename the columns to mathc what is expected from
  # AnomalyDetection() internals
  colnames(data) <- c("timestamp", "count")
  
  data[is.na(data[, 2]), 2] <- 0
  a_result <- AnomalyDetection::AnomalyDetectionTs(
    data,
    plot = T,
    direction = direction,
    piecewise_median_period_weeks = piecewise_median_period_wk,
    max_anoms = anoms,
    longterm = longterm,
    title = title,
    y_log = y_log
  )
  # if there are more than 0 anomalies, generate plots
  if (nrow(a_result$anoms[2]) > 0) {
    sstats = summary(data)
    # png(anomaly_plot)
    a_result$plot +
      hrbrthemes::scale_color_ipsum() +
      ggplot2::ylab("# Events") +
      ggplot2::xlab("Date") +
      hrbrthemes::theme_ipsum_rc(grid = "X") +
      ggplot2::theme(
        axis.text.y = element_text(size = 15),
        axis.text.x = element_text(size = 15),
        legend.position = "bottom",
        legend.text = element_text(size = 0)
      )
  }
  else
    break
}
