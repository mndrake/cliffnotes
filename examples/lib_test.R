library(cliffnotes)
library(dplyr)
library(nycflights13)
library(readr)

cliffnotes(flights)
cliffnotes(airports)
cliffnotes(weather)

df <- flights
df$delay15 <- !(is.na(df$dep_delay) | df$dep_delay < 15)

cliffnotes(df)


library(lubridate)
library(stringr)
library(jsonlite)
source('R/library.R')


df_summary <- get_data_frame_summary(df)
toJSON(df_summary) %>% write('data.txt')
