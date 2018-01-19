# googleAnalyticsProphetR
Applying Facebook's prophet on Google Analytics data

# Motivation
One the problems we have in Digital Analytics is figuring out when something has stopped recording or fires more frequently that it should (you know ; fire once per page vs per event).

# Strategy
In this attempt we are taking a data-driven approach to detecting deviations from the "expected" (ref: remains to be defined). One of the most accesible ways to get a estimation of "expected" is by using Facebook's [prophet]() API which is available both in R and Python. The proposed strategy is to create daily the prediction for the previous day and compare it to the actual count of events in discussion.

In practice, prophet does really well in point estimation but we can also get upper and lower prediction bounds. Actually, we will trigger an alert when the actual value is outside these bounds.

# Under the hood
To create the we have wrapped somethings around the following functions that are originating from [googleAnalyticsR()]() and [prophet()]() :

- [`get_ga_data()`]()
- [`get_prophet_prediction()`]()
- [`get_prophet_prediction_graph()`]()

*Side note* : Actually there is another function that is based on Twitter's awesome [AnomalyDetection]() package (only for R).

# Example(s)
There is a sample RNotebook under the Reports folder ([report.rmd]()) that you can use with minimal configuration.

## Configuration
### Packages
As usual you will need to have all the packages mentioned on the [requirements.R]() file.

### Authentication
Then you will need to authenticate to Google via any method you like and is provide in [googleAuthR](), in the example I authenticate once and then reuse the `.httr-oauth`. A deeper explanation of authentication can be found [here]().

### Parameters
You will need to pass your `GA_VIEW_ID` for the API calls and your dimensions and metric of interest (default :  `totalEvents`). Since we need to have a time series by the definition of the problem `date` is always added in the dimensions.


