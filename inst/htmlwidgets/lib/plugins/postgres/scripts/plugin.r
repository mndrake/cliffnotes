`_tam_queryPostgres` <- function(host, port, databaseName, username, password, numOfRows = -1, query){
  exploratory::queryPostgres(host, port, databaseName, username, password, numOfRows, query)
}
