library(cliffnotes)

df <- readr::read_csv('scratch/flights.csv')
cliffnotes(df)

library(nycflights13)
cliffnotes(flights)
