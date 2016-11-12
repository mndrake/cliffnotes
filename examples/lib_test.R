library(cliffnotes)
library(dplyr)
library(nycflights13)

cliffnotes(nycflights13::flights)
cliffnotes(nycflights13::airports)
cliffnotes(nycflights13::weather)

weather_df <- nycflights13::weather
weather_df %>% mutate(month = as.integer(month)) %>% cliffnotes

flights_df <- nycflights13::flights
flights_df$delay15 <- !(is.na(flights_df$dep_delay) | flights_df$dep_delay < 15)
cliffnotes(flights_df)
