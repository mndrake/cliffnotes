`_tam_queryMongoDB` <- function(host, port, database, collection, username, password, query = "{}", isFlatten, limit=100000){
  exploratory::queryMongoDB(host, port, database, collection, username, password, query, isFlatten, limit)  
}
