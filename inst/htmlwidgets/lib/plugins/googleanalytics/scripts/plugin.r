# tokenFileId is a unique value per data farme and is used to create a token cache file
`_tam_getGoogleTokenForAnalytics` <- function(tokenFileId, useCache=TRUE){
  exploratory::getGoogleTokenForAnalytics(tokenFileId, useCache)
}

# API to refresh token
`_tam_refreshGoogleTokenForAnalysis` <- function(tokenFileId){
  exploratory::refreshGoogleTokenForAnalysis(tokenFileId)
}

`_tam_getGoogleAnalytics` <- function(tableId, lastNDays, dimensions, metrics, tokenFileId, paginate_query=FALSE){
  exploratory::getGoogleAnalytics(tableId, lastNDays, dimensions, metrics, tokenFileId, paginate_query)
}
# API to get profile for current oauth token
`_tam_getGoogleProfile` <- function(tokenFileId){
  exploratory::getGoogleProfile(tokenFileId)
}
