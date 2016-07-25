`_tam_queryMySQL` <- function(host, port, databaseName, username, password, numOfRows = -1, query){
  exploratory::queryMySQL(host, port, databaseName, username, password, numOfRows, query);
}
