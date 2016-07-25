
# tokenFileId is a unique value per data farme and is used to create a token cache file
`_tam_getGoogleTokenForSheet` <- function(tokenFileId, useCache=TRUE){
  require(httr)
  require(stringr)
  # As per Kan, this can be hard coded since Google limits acces per ViewID (tableID) and
  # not by clientID
  clientId <- "1066595427418-aeppbdhi7bj7g0osn8jpj4p6r9vus7ci.apps.googleusercontent.com"
  secret <-  "wGVbD4fttv_shYreB3PXcjDY"
  cacheOption = getOption("tam.oauth_token_cache")
  # tam.oauth_token_cache is path ~/.exploratory/projects/<projectid>/rdata/placeholder.rds is the rds file templatettr cache
  # for each data set, create token cache as 
  # ~/.exploratory/projects/<projectid>/rdata/<tokenFileId_per_dataframe>_gs_token.rds
  tokenPath = str_replace(cacheOption, "placeholder.rds", str_c(tokenFileId, "_gs_token.rds"))
  # use oauth_app and oauth2.0_token
  token <- NULL
  if(useCache == TRUE && file.exists(tokenPath)){
    token <- readRDS(tokenPath)
  } else {
    myapp <- oauth_app("google", clientId, secret)
    # scope is same as gs_auth does
    scope_list <- c("https://spreadsheets.google.com/feeds","https://www.googleapis.com/auth/drive")
    token <- oauth2.0_token(oauth_endpoints("google"), myapp,
                    scope = scope_list, cache = FALSE)
    # Save the token object for future sessions		
    saveRDS(token, file=tokenPath)
  }
  token
}

# API to refresh token
`_tam_refreshGoogleTokenForSheet` <- function(tokenFileId){
  `_tam_getGoogleTokenForSheet`(tokenFileId, FALSE)
}

`_tam_getGoogleSheet` <- function(title, sheetNumber, skipNRows, treatTheseAsNA, firstRowAsHeader, commentChar, tokenFileId){
  require(googlesheets)
  token <- `_tam_getGoogleTokenForSheet`(tokenFileId)
  gs_auth(token)
  gsheet <- gs_title(title)
  df <- gsheet %>% gs_read(ws = sheetNumber, skip = skipNRows, na = treatTheseAsNA, col_names = firstRowAsHeader, comment = commentChar)
  df
}

# API to get a list of available google sheets
`_tam_getGoogleSheetList` <- function(tokenFileId){
  require(googlesheets)
  token = `_tam_getGoogleTokenForSheet`(tokenFileId)
  gs_auth(token)
  gs_ls()
}
