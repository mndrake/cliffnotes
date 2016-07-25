# tokenFileId is a unique value per data farme and is used to create a token cache file
`_tam_getTwitterToken` <- function(tokenFileId, useCache=TRUE){
  require(twitteR)
  require(httr)
  
  consumer_key = "0lWpnop0HLfWRbpkDEJ0XA"
  consumer_secret = "xYNUMALkRnvuT3vls48LW7k2XK1l9xjZTLnRv2JaFaM"

  cacheOption = getOption("tam.oauth_token_cache")
  # tam.oauth_token_cache is RDS file path (~/.exploratory/projects/<projectid>/rdata/placeholder.rds)
  # for each data frame, create token cache as 
  # ~/.exploratory/projects/<projectid>/rdata/<tokenFileId_per_dataframe>_ga_token.rds
  tokenPath = str_replace(cacheOption, "placeholder.rds", str_c(tokenFileId, "_twitter_token.rds"))
  
  twitter_token <- NULL
  if(useCache == TRUE && file.exists(tokenPath)){
    twitter_token <- readRDS(tokenPath)
  } else {
    myapp <- oauth_app("twitter", key = consumer_key, secret = consumer_secret)
    # Get OAuth credentials (For twitter use OAuth1.0)
    twitter_token <- oauth1.0_token(oauth_endpoints("twitter"), myapp, cache = FALSE)
    # Save the token object for future sessions		
    saveRDS(twitter_token, file=tokenPath)
  }
  twitter_token
}

# API to refresh token
`_tam_refreshTwitterToken` <- function(tokenFileId){
  `_tam_getTwitterToken`(tokenFileId, FALSE)
}

`_tam_getTwitter` <- function(n=200, lang=NULL,  lastNDays=30, searchString, tokenFileId){  
  require(twitteR)
  require(lubridate)
  
  twitter_token = `_tam_getTwitterToken`(tokenFileId)
  use_oauth_token(twitter_token)
  # this parameter needs to be character with YYYY-MM-DD format
  # to get the latest tweets, pass NULL for until
  until = NULL
  since = as.character(today() - days(lastNDays))  
  locale = NULL
  geocode = NULL
  sinceID = NULL
  maxID = NULL
  # hard cocde it as recent for now
  resultType = "recent"
  retryOnRateLimit = 120  
  
  tweetList <- searchTwitter(searchString, n, lang, since, until, locale, geocode, sinceID, maxID, resultType, retryOnRateLimit)
  # conver list to data frame
  if(length(tweetList)>0){
   twListToDF(tweetList)
  } else {
   stop('No Tweets found.')
  }
}
