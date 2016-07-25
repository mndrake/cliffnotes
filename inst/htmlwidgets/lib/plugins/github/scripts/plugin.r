`_tam_getGithubIssues` <- function(username, password, owner, repository){
  # read stored password
  pass = `_tam_saveOrReadPassword`("github", username, password)
  
  # Body
  endpoint <- str_c("https://api.github.com/repos/", owner, "/", repository, "/issues")
  pages <- list()
  is_next <- TRUE
  i <- 1
  while(is_next){
    res <- GET(endpoint, 
               query = list(state = "all", per_page = 100, page = i),
               authenticate(username, pass))
    jsondata <- content(res, type = "text", encoding = "UTF-8")
    github_df <- jsonlite::fromJSON(jsondata, flatten = TRUE)
    pages[[i]] <- github_df
    
    # check if link exists
    if(is.null(res$headers$link)){
      is_next <- FALSE
    } else {
      is_next <- str_detect(res$headers$link, "rel=\"next\"")  
      i <- i + 1
    }
  }
  issues <- bind_rows(pages)
}
