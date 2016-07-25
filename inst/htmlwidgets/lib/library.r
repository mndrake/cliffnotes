#
# TODO: Check out the location of this file at the production build
#

# TODO: evaluate detaching datasets package
# To prevent unwanted objects show up in candidates for
# auto complete, unload datasets packages from session.
# detach(package:datasets)


# Set LANG environment variable.
# This seems to control language of error message (and probably some other things) in R.
Sys.setenv(LANG = "en_US.UTF-8")
Sys.setenv(LC_CTYPE = "en_US.UTF-8")
# This variable affects whether readr can read Japanese.
Sys.setlocale(category = "LC_CTYPE", locale = "en_US.UTF-8")
# "libcurl" seems to make quantmod::getFX work.
options(download.file.method = "libcurl")

# Set cache path for oauth token cachefile
`_tam_setOAuthTokenCacheOptions` <- function(path){
  options(tam.oauth_token_cache = path)
}

# Set TAM required Package List
`_tam_setTamRequiredPackageList` <- function(packageList){
  options(tam.required_package_list = packageList)
}

# Executes Apache Drill SQL
`_tam_executeSQLQuery` <- function(queryStr){
 url<-"http://localhost:8047/query.json";
 request <- list('queryType'="SQL", 'query'= queryStr);
  response <- POST(url, body = request, , encode = "json");
 c <- content(response, "text", 'encoding'='UTF-8');
 d <- jsonlite::fromJSON(c);
 # throw error if the request fails
 if (response$status_code == 500) {
   stop(d$errorMessage)
 }
 a <- d$rows;
 a <- a[d$columns];
 a[] <- lapply(a, function(x) type.convert(as.character(x), as.is = TRUE));
 a;
}

# For auto-complete
`_tam_autoComplete` <- function(input){
 require(jsonlite)
 utils:::.assignLinebuffer(input)
 utils:::.assignEnd(nchar(input) - 1)
 utils:::.guessTokenFromLine()
 utils:::.completeToken()
 autocomps = utils:::.retrieveCompletions()
 autocompleteList <- lapply(autocomps, function(x){
   result = ""
   noArgs = FALSE
   if(identical(environment(x), baseenv())){
     result = ""
   } else {
     res <- methods::findFunction(x);
     if(length(res) > 0){
        env <- res[[1]]
        if(identical(env,baseenv())){
          result = "package:base"
          noArgs = is.null(formals(x))
        } else if (identical(env, globalenv())){
          result = "globalEnv"
          noArgs = is.null(formals(x))
        } else {
          name <- attr(env, "name")
          if(!is.null(name)){
           result = name
           noArgs = is.null(formals(x))
          } else {
           result = ""
          }
        }
     }
   }
   try(
     if(result == ""){
       objClass <- class(eval(parse(text = x)))
       # Need to exclude followings:
       #
       # data.frame (user defined)
       # xxx.timestamp (whose object class is c("POSIXct","POSIXt"))
       #
       # Also seed data from datasets package needs to be excluded
       #
       if(objClass == "data.frame" || (regexpr('.timestamp',x) > 0 && objClass == c("POSIXct", "POSIXt")) ){
         result = "tam:needtoignore"
       } else if((objClass == "ts" || objClass == "matrix" || objClass == "table" || objClass == "array" ||
          objClass == "tbl_cube" || objClass == "mts" || objClass == "nfnGroupedData" || objClass == "nfGroupedData" || 
          objClass == "groupedData" ||
          objClass == "numeric" || objClass == "character" || objClass == "list" || objClass == "factor" || 
          objClass == "dist") &&  x %in% ls() == FALSE){
         result = "seeded:data"
       }
     }, silent = TRUE
   ) 
   c(x, result, noArgs)
 })
 df <- as.data.frame(autocompleteList);
 df2 <- t(df)
 jsonlite::toJSON(df2)
}

# Comment out the _tam_getDateBreaks since we do not use this for now.
# Returns appropriate breaks value for histogram for date
# `_tam_getDateBreaks` <- function(x) {
#  a <- min(x, na.rm = TRUE)
#  b <- max(x, na.rm = TRUE);
#  timeinterval <- interval(a,b)
#  cbreaks <- "years"
#  if (time_length(timeinterval, "year") < 2) {
#    cbreaks <- "months"
#    if (time_length(timeinterval, "month") <2) {
#      cbreaks <- "days"
#      if (time_length(timeinterval, "day") < 2 && is.POSIXt(x)) {
#        cbreaks <- "hours"
#        if (time_length(timeinterval, "hour") <2) {
#          cbreaks <- "mins"
#          if (time_length(timeinterval, "minute") <2) {
#            cbreaks <- "sec"
#          }
#        }
#      }
#    }
#  }
#  return(cbreaks);
#} 

# Returns appropriate date format string 
`_tam_getFormatString` <- function(mindate, maxdate) {
  timeinterval <- interval(mindate, maxdate)
  str <- "%Y"
  if (time_length(timeinterval, "month") < 12) {
    str <- "%Y-%m"  
    if (time_length(timeinterval, "day") < 31) {
      str <- "%Y-%m-%d"
      if (time_length(timeinterval, "hour") < 48) {
        str <- '%H:%M:%S'
      }
    }
  }
  return(str);
} 

# Return dataframe summary info
# @param x dataframe
`_tam_getSummary` = function(x) {
  # calculate uniq length for each column in advance because
  # we use those numbers multiple times later and it is a costly operation.
  .uniqlen <- sapply(x, function(y) {
    # We need number of unique values only for character columns. 
    if (is.character(y)) {
      return (length(unique(y)))
    } else {
      # to align with js side cache, return -1 instead of 0 so that later js side can know it needs to query unique value for 
      # this column
      return (-1)
    }
  }, simplify=FALSE)
   
  res <- list(
    # 0: column names  
    colnames(x),
   
    # 1: column classes  
    sapply(x, function(x){ paste(class(x), collapse=",")}, simplify=FALSE),  
   
    # 2: summary() for each column 
    sapply(colnames(x), function(colname) { 
      col <- x[[colname]]
      # This command itself may return more than 1 length of index numbers
      # but it shouldn't happen technically because each column name should be
      # unique by repair_names(). 
      colidx <- which(colnames(x) %in% colname)
      # if the estimate is greater than 1 sec, skip it
      # ref: https://github.com/hideaki/tam/pull/927

      # as.vector is required because jsonlite cannot deserialize table class
      # data that summary command returns. There's no much performance with 
      # or without as.vector. 
      #
      # > system.time(summary(data))
      #    user  system elapsed 
      #   3.350   0.528   3.881 
      # > system.time(as.vector(summary(data)))
      #    user  system elapsed 
      #   3.334   0.515   3.853       

      # supported data types on summary view
      # list, difftime, Duration, Interval, numeric, integer, Date, POSIXct, 
      # POSIXlt, logical, character, factor

      if (is.character(col)){
        #uniqueLength <- length(unique(x))
        if(.uniqlen[colname] > 120000){ # from our observation it takes more than 1 sec if unique length is greater than 120K
          return (c('first6rows', head(col, 6), paste0('NAs:', as.character(sum(is.na(col))))))
        } else {
          return (as.vector(summary(data.frame(col)))); 
        }
      } else if (is.list(col)) {
        if (is(col, ".model")) { 
          s6<-head(col, 6)
          lst<- list()
          for (i in 1:length(s6)) {
            .t<-tidy(s6[[i]])
            .g<-glance(s6[[i]])
            lst[[i]] <-  toJSON( list(.t, sapply(.t, is.numeric, simplify=FALSE), .g, sapply(.g, is.numeric,  simplify=FALSE)) )
          }
          return(toJSON(lst))
        } else if (is(col, ".source.data")) { 
          return(c(0)) 
        } else {
          return (c('first6rows', as.character(head(col), 6), paste0('NAs:',as.character(sum(is.na(col))))))
        }
      } else if (is.difftime(col)) {
        return (as.vector(summary(data.frame(as.numeric(col))))); 
      } else if (is(col, 'time')) {
        # instead of creating dataframe by data.frame, use select to create a data frame
        # with a single column because you cannot construct a data frame from a vector with
        # certain data type such as time. 
        return (as.vector(summary(select(x, colidx)))); 
      } else if (is.numeric(col) || is.factor(col)|| is.duration(col) ||
                 is.interval(col) || is.logical(col) || is.Date(col) || is.POSIXt(col)){  
        return (as.vector(summary(data.frame(col)))); 
      } else {
        # if not supported data type, no process and just return empty.
        return(c(0)) 
      }
       
    }, simplify=FALSE), 
     
    # 3: histogram 
    # Please refer https://github.com/hideaki/tam/issues/1037 for the changes
    # around breaks as.Date/POSIXct/POSIXlt
    # We use fixed number (12) as breaks as opposed to time-unit like "month", 
    # so that we can avoid the case like 15 months period is broken 
    # into 12 one-month-length buckets and 
    # 3 months worth of data points wrapping around.
    #
    # Note that we need mid values for chart rendering. 
    sapply(x, function(x) { 
      # Exclude the case if all the data is NA - hist() will complain that case.
      if (all(is.na(x)) == FALSE) {   
        if (is.numeric(x)){   # number types, duration, period, interval
          .a<- hist(x, plot=FALSE); 
          return (list(.a$breaks, .a$counts, .a$mids, 0)) 
        } else if (is.difftime(x)){   # difftime
          .a<- hist(as.numeric(x), plot=FALSE); 
          return (list(.a$breaks, .a$counts, .a$mids, 0)) 
        } else if (is.Date(x)) {
          .a<- hist(x, plot=FALSE, breaks=12); 
          .a$breaksdate <- as.character(as.Date(.a$breaks, origin="1970-01-01")); 
          .a$midsdate <- as.character(as.Date(.a$mids, origin="1970-01-01"));
          return (list(.a$breaksdate, .a$counts, .a$midsdate, c(12)))  
        } else if (is.POSIXct(x)) {  
          .a<- hist(x, plot=FALSE, breaks=12); 
          fmtstr <- `_tam_getFormatString`(as.POSIXct(head(.a$breaks, n=1),origin="1970-01-01") , as.POSIXct(tail(.a$breaks, n=1),origin="1970-01-01")) 
          .a$breaksdate <-  format(as.POSIXct(.a$breaks, origin="1970-01-01"), fmtstr);
          return (list(.a$breaksdate, .a$counts, .a$mids, c(12), fmtstr))  
        } else if (is.POSIXlt(x)) {  
          .a<- hist(x, plot=FALSE, breaks=12); 
          fmtstr <- `_tam_getFormatString`(as.POSIXlt(head(.a$breaks, n=1),origin="1970-01-01"), as.POSIXlt(tail(.a$breaks, n=1),origin="1970-01-01"))
          .a$breaksdate <-  format(as.POSIXlt(.a$breaks, origin="1970-01-01"), fmtstr);
          return (list(.a$breaksdate, .a$counts, .a$mids, c(12), fmtstr))
        } else { 
          return( c(0)) 
        }
      } else { 
        return(c(0)) 
      }
    }, simplify=FALSE),
     
    # 4: num of rows  
    nrow(x), 
     
    # 5: number of NAs - not used anymore 
    sapply(x, function(x) c(0), simplify=FALSE), #returns 0 all the time
     
    # 6: number of unique values  
    .uniqlen,
     
    # 7: boxplot info  
    # Currently disabled because of performance reason.
    sapply(x, function(x) c(0), simplify=FALSE), #returns 0 all the time
    # sapply(x, function(x) {
    #   if (is.numeric(x) & !is.period(x) & !is.duration(x) & !is.interval(x)) {
    #     q <- quantile(x, na.rm = TRUE);
    #     IQR <- q[4]-q[2];
    #     upper_whisker <- q[4]+1.5*IQR;
    #     lower_whisker <- q[2]-1.5*IQR;
    #     outdata_size <- sum(x>upper_whisker | x<lower_whisker, na.rm = TRUE);
    #     return (list(outdata_size, outdata_size/length(x)))
    #   } else { 
    #     return( c(0)) 
    #   }
    # }, simplify=FALSE),

    # 8: text max length
    sapply(x, function(x) { 
      if (is.character(x)){ 
        return (max(str_length(x), na.rm=TRUE))
      } else if (is.factor(x)) { 
        return (max(str_length(as.character(x)), na.rm=TRUE))
      } else { 
        return(c(0)) 
      }
    }, simplify=FALSE),
   
    # 9: text min length
    sapply(x, function(x) { 
      if (is.character(x)){ 
        return (min(str_length(x), na.rm=TRUE))
      } else if (is.factor(x)) { 
        return (min(str_length(as.character(x)), na.rm=TRUE))
      } else { 
        return( c(0))
      }
    }, simplify=FALSE),

    # 10: safe (properly escaped) column names
    sapply(colnames(x), function(x) { capture.output(as.name(x)) })
  )
  return (res);
}


# Flatten the list columns in the given data frame into character columns.
`_tam_flattenDataFrame` = function(df){
  islist <- sapply(df, is.list)
  df[islist] <- lapply(df[islist], function(x) {
    if (is(x, ".model")) { 
      # send captured output back in json format 
      lst<- list()
      for (i in 1:length(x)) {
        .t<-tidy(x[[i]])
        .g<-glance(x[[i]])
        lst[[i]] <-  toJSON( list(.t, sapply(.t, is.numeric, simplify=FALSE), .g, sapply(.g, is.numeric,  simplify=FALSE)) )
      }
      return(lst)
    } else if (is(x, ".source.data")) {  
      y <- "<source data>"
      class(y) <- c("list", ".source.data")
      return (y)
    } else {
      y <- as.character(x)
      # Add dummy "list" class to show "list" on the preview column header
      class(y) <- c("list", "character")
      return (y)
    }
  }) 
  return (df)
}

# Create a data frame from the given list object
# `_tam_listToDataFrame` <- function(x, id = ".group.id") {
#   if(is.list(x[[1]])) {
#     df <- bind_rows(x, .id = id) 
#   } else {
#     df <- as_data_frame(x)
#   }
# }
 
# Create a data frame from the given object that can be transformed to data frame.
`_tam_toDataFrame` <- function(x) {
  if(is.data.frame(x)) { 
    df <- x 
  } else if (is.matrix(x)) { 
    df <- as.data.frame(x, stringsAsFactors = FALSE)
  } else {
    # just in case for other data type case in future
    df <- as.data.frame(x, stringsAsFactors = FALSE)
  }
  return(`_tam_typeConvert`(df))
}


# Construct a data frame from json or ndjson data
# ndjson stands for "Newline Delimited JSON" and 
# each line of ndjson data is a valid json value.
# http://ndjson.org/
#
# ndjson format is popular and used in many places such as
# Yelp academic data is based on.
#
# jsonlite::fromJSON can read standard json but not ndjson.
# jsonlite::stream_in can read ndjson but not standard json.
# This function internally detects the data type and 
# calls the appropriate function to read the data 
# and construct a data from either json or ndjson data. 
#
# x: URL or file path to json/ndjson file
# flatten: TRUE or FALSE. Used only json case
# limit: Should limit the number of rows to retrieve. Not used now
# since underlying technology (jsonlite) doesn't support it.
`_tam_fromJSON` <- function(x, flatten=TRUE, limit=0) {
  if (`_tam_isNDJSON`(x) == TRUE) {
    con2 <- `_tam_getConnection`(x)
    df <- stream_in(con2, pagesize=1000, verbose=FALSE)
    
    # In case of connectinng to url, the following close call may fail with;
    # Error in close.connection(con2) : invalid connection 
    # so here we catch the error here not to block the process.
    tryCatch (
      {
        close(con2)
      },
      error=function(cond){
      }
    )
    if (flatten == TRUE) {
      df <- flatten(df)
    }
    return (df)
  } else {
    df <- jsonlite::fromJSON(x, flatten=flatten)
    return (df)
  }
}


# Checks and tells the given data is whether in ndjson format
# by looking at that the first line is a valid json or not.
# x - URL or file path
`_tam_isNDJSON` <- function(x) {
  con <- `_tam_getConnection`(x)
  line <- readLines(con, n=1, warn=FALSE)
  close(con)
  tryCatch (
    {
      # It errors out if the line is invalid json.
      obj <- jsonlite::fromJSON(line)
      return (TRUE)
    },
    error=function(cond){
      return (FALSE)
    }
  )
}

# Gives you a connection object based on the given 
# file locator string. It supports file path or URL now.
# x - URL or file path
`_tam_getConnection` <- function(x) {
  if (str_detect(x, "://")) {
    return(url(x))
  } else {
    return(file(x, open = "r"))
  }
}  

# Run the type convert if it is a data frame.
`_tam_typeConvert` <- function(x) {
  if (is.data.frame(x))  type_convert(x) else x
}

# Prepare srcfile for _tam_getRParseTree.
`_tam_tempSrcfile` <- srcfile("tmp")

# Gets R parse tree in json format
#
# 1. Reason of using latin1 encoding for parser for syntax helper.
# encoding = "UTF-8" did not give token position
# (col1, col2 in the table returned from getParserData().)
# as expected. (return value is as if multibyte char part did not exist.)
# As a work-aboud, we are using encoding = "latin1", which seems to give
# token positions in byte count.
# When we search for token that matches cursor position later, we will
# use byte count instead of char count.
# See comment in DpyrPredictor.predictInternal().
#
# 2. Reason of calling dummy parse() function with encoding = "UTF-8"
# It is to work around this issue. https://github.com/hideaki/tam/issues/1098
# Calling intentionally failing parse() call with encoding = "UTF-8" gets
# R out of the strange state where filter with multibyte chars fails.
`_tam_getRParseTree` <- function(x, use_latin1) {
  tryCatch(parse(text = x, srcfile = `_tam_tempSrcfile`, encoding = ifelse(use_latin1, "latin1", "UTF-8")), error = function(e){})
  if (use_latin1) {
    tryCatch(parse(text = "()", encoding = "UTF-8"), error = function(e){})
  }
  return(jsonlite::toJSON(getParseData(`_tam_tempSrcfile`)))
}

# This function converts the given data frame object to JSON.
# The benefit of using this function is that it can converts 
# the column data types that cannot be serialized by toJSON 
# to safe ones. 
`_tam_toJSON`  <- function(x) {
  require(jsonlite)
  .tmp.tojson <- x  
  isdifftime <- sapply(.tmp.tojson, is.difftime)
  .tmp.tojson[isdifftime] <- lapply(.tmp.tojson[isdifftime], function(y) as.numeric(y)) 
  isperiod <- sapply(.tmp.tojson, is.period)
  .tmp.tojson[isperiod] <- lapply(.tmp.tojson[isperiod], function(y) as.character(y)) 
  jsonlite::toJSON(.tmp.tojson)
}

lookup <- function(x, kv, keep = TRUE) {
  new_values_list <- unname(kv[as.character(x)])
  if(keep){
    new_values_list[is.na(new_values_list)] <- as.character(x[is.na(new_values_list)])
  }
  new_values_list
}

# Wrapper function for runing lm with broom
# do_lm <- function(df, ...){
#   loadNamespace("dplyr")
#   output <- df %>% dplyr::do(.model= do.call("lm",list(data=., ...)))
#   class(output$.model) <- c("list", "model-lm")
#   output
# }

# Wrapper function for kmean with broom
# do_kmeans <- function(df, ..., groups = 2, type = "augment", seed = 0){
#   loadNamespace("broom")
#   set.seed(seed)
#   columns <- as.character(substitute(list(...)))[-1L]
#   # default, all columns
#   if(length(columns)==0) columns <- colnames(df)
#   mat <- create_matrix(df, columns)
#   # remove na rows
#   omit_mat <- na.omit(mat)
#   if(nrow(omit_mat) == 0){
#     stop("all rows have NA")
#   }
#   if(type == "augment"){
#     removed_row <- attr(omit_mat, "na.action")
#     if(is.null(removed_row)){
#       broom::augment(kmeans(omit_mat, groups), df)
#     } else {
#       broom::augment(kmeans(omit_mat, groups), df[-removed_row,])
#     }
#   }else if(type == "glance"){
#     broom::glance(kmeans(omit_mat, groups))
#   }else{
#     broom::tidy(kmeans(omit_mat, groups))
#   }
# }

# function to convert labelled class to factoror
# see https://github.com/exploratory-io/tam/issues/1481
`_tam_handleLabelledColumns` = function(df){
  is_labelled <- which(lapply(df, class) == "labelled")
  df[is_labelled] <- lapply(df[is_labelled], as_factor) 
  df
}

# Function to create binary vector of set
set_to_vec <- function(word_list, sparse = FALSE) {
  loadNamespace("Matrix")
  # create word set vector
  all_word <- unique(unlist(word_list))
  lapply(word_list, function(word){
    # make binary vector whether the entity exists in the subset or not
    if(sparse){
      methods::as(as.integer(all_word %in% word), "sparseVector")
    } else {
      vec <- all_word %in% word
      names(vec) <- all_word
      vec
    }
  })
}

# Function to create terms list
get_terms <- function(text, vocab = NULL, stemmer = NULL, tolower = TRUE, ngram = 1, skip = 0){
  # making terms using skipgram
  end_of_sentence <- "[.|\n|?|!]"
  split_text <- stringr::str_split(text, end_of_sentence)
  val <- lapply(split_text, function(sentences){
    # tokenize for each sentence
    non_empty <- sentences[sentences != ""]
    val <- unlist(lapply(non_empty, function(sentence){
      # all terms in the sentence
      token <- text2vec::word_tokenizer(sentence)[[1]]
      if(tolower){
        token <- tolower(token)
      }
      if(is.character(stemmer) && stemmer=="porter"){
        token <- quanteda::wordstem(token, language = stemmer)
      } else if(!is.null(stemmer) && is.function(stemmer)){
        token <- stemmer(token)
      } else if(!is.null(stemmer)){
        stop("stemmer has to be a function or 'porter'")
      }
      token <- quanteda::skipgrams(token, n=ngram, skip=skip)
      if(!is.null(vocab)) {
        # return terms only in vocab
        token[token %in% vocab]
      }else{
        token
      }
    }))
    if(is.null(val)){
      character(0)
    }else{
      val
    }
  })
  if(length(val) ==0){
    character(0)
  }else{
    val
  }
}

# Function to create vocabulary data frame
build_vocabulary <- function(df, token_col, term_count_min = 0, term_count_max = Inf, doc_proportion_min = 0, doc_proportion_max = 1) {
  token <- text2vec::itoken(df[[as.character(substitute(token_col))]], progessbar=FALSE)
  vocab <- text2vec::create_vocabulary(token)
  pruned_vocab <- text2vec::prune_vocabulary(
    vocab,
    term_count_min = term_count_min,
    term_count_max = term_count_max,
    doc_proportion_min = doc_proportion_min,
    doc_proportion_max = doc_proportion_max
  )
  # data frame with terms, terms_counts, doc_counts
  pruned_vocab$vocab
}

# Function to create tf-idf vector
get_tfidf <- function(tokens, vocab = NULL, sparse = TRUE) {
  if(is.null(vocab)){
    token <- text2vec::itoken(tokens, progessbar = FALSE)
    vocab <- text2vec::create_vocabulary(token)
  } else {
    # argument of itoken have to be a list
    token <- text2vec::itoken(list(vocab), progessbar = FALSE)
    vocab <- text2vec::create_vocabulary(token)
  }
  vectorizer <- text2vec::vocab_vectorizer(vocab)
  token <- text2vec::itoken(tokens, progessbar = FALSE)
  dtm <- text2vec::create_dtm(token, vectorizer)
  tfidf <- text2vec::transform_tfidf(dtm)
  lapply(seq(nrow(tfidf)), function(row){
    if(sparse){
      as(tfidf[row,], "sparseVector")
    }else{
      tfidf[row,]
    }
  })
}

# Private function to create matrix from data frame and columns.
# This function can handle columns whose type is list, by expanding
# each index position of list as a matrix column.
create_matrix <- function(df, columns){
  cols <- lapply(columns, function(column){
    rows <- lapply(df[[column]], function(data){
      suppressWarnings(as.numeric(data))
    })
    tryCatch({
      # rbind causes error or warning if number of columns is different among rows
      mat <- do.call(rbind, rows)
      # put names to recognize which columns are from which data
      if(is.list(df[[column]])){
        first_data <- df[[column]][[1]]
        data_names <- names(first_data)
        if(!is.null(data_names)){
          # if the vector has names, use them as postfix
          colnames(mat) <- paste(column, data_names, sep=".")
        } else {
          # otherwise use index for postfix
          colnames(mat) <- paste(column, 1:length(first_data), sep=".")
        }
      } else {
        colnames(mat) <- column
      }
      mat
    }, error=function(e){
      stop(paste(column,"doesn't have the same length of numbers", collapse=" "))
    }, warning=function(w){
      # not same length warning
      if(grepl("^number of columns of result is not a multiple of vector length", w$message)){
        stop(paste(column,"doesn't have the same length of numbers", collapse=" "))
      }
    })
  })
  do.call(cbind,cols)
}

# function to read text file
# see https://github.com/exploratory-io/tam/issues/1598
# use read_lines, which supports locale (not only encoding but also date_time that can be used in future)
# instead of base function readLines, which only support encoding 
`_tam_readTextFile` = function(filePath, firstNrow, encoding){
  loc <- locale(encoding = encoding)
  lines <- read_lines(filePath, n_max=firstNrow, locale=loc)
  jsonlite::toJSON(as.list(lines))
}

# function to get group columns array for transform
# if transform is not grouped, it returnes empty array
`_tam_getGroupColumns` = function(transformName){
  jsonlite::toJSON(as.character(groups(transformName)))
}

# function to get number of groups for transform
# if transform is not grouped, it returnes [0]
`_tam_getNGroup` = function(transformName){
  # according to Kan n_groups is not stable, so we expliclity call group_size and then check length of it.
  jsonlite::toJSON(transformName %>% group_size() %>% length())
}


# API to take care of read/save password for each plugin type and user name combination
# if password argument is null, it means we need to retrieve password from RDS file
# so the return value is password from RDS file.
# if password argument is not null, then it means it creates a new password or updates existing one
# so the password is saved to RDS file and the password is returned to caller
`_tam_saveOrReadPassword` = function(source, username, password){
  # read stored password
  pass = `_tam_readPasswordRDS`(source, username)
  # if stored password is null (i.e. new cteation) or stored password is different from previous (updating password from UI)
  if(is.null(pass)) {  
     #if not stored yet, get it from UI
     pass = password
    `_tam_savePasswordRDS`(source, username, pass)
  } else if (!is.null(pass) & password != "" & pass != password) {
    #if passord is different from previous one, then  update it
    pass = password
   `_tam_savePasswordRDS`(source, username, pass)
  }
  pass
}

# API to read a password from RDS
# password file is consturcted with <source>_<username>.rds format_
`_tam_readPasswordRDS` = function(sourceName, userName){
  loadNamespace("sodium")
  passwordFlePath <- str_c("../rdata/", sourceName, "_", userName, ".rds")
  password <- NULL
  if(file.exists(passwordFlePath)){
    # tryCatch so that we can handle decription failure
    tryCatch({
      cryptoKeyPhrase = getOption("tam.crypto_key")
      key <- sodium::hash(charToRaw(cryptoKeyPhrase))
      noncePhrase = getOption("tam.nonce")
      nonce <- sodium::hash(charToRaw(noncePhrase), size=24)

      cipher <- readRDS(passwordFlePath)
      msg <- sodium::data_decrypt(cipher, key, nonce)
      password <-unserialize(msg)
    }, warning = function(w) {
    }, error = function(e) {
    })
  }
  password
}
# API to save a psssword to RDS file
# password file is consturcted with <source>_<username>.rds format_
`_tam_savePasswordRDS` = function(sourceName, userName, password){
  loadNamespace("sodium")
  cryptoKeyPhrase = getOption("tam.crypto_key")
  key <- sodium::hash(charToRaw(cryptoKeyPhrase))
  noncePhrase = getOption("tam.nonce")
  nonce <- sodium::hash(charToRaw(noncePhrase), size=24)
  msg <- serialize(password, NULL)
  cipher <- sodium::data_encrypt(msg, key, nonce)
  saveRDS(cipher, file= str_c("../rdata/", sourceName, "_", userName, ".rds"))
}
# ref: http://stackoverflow.com/questions/6979917/how-to-unload-a-package-without-restarting-r
`_tam_detachPackage` <- function(pkg) {  
  search_item <- paste("package", pkg, sep = ":")
  while(search_item %in% search()){
    detach(search_item, unload = TRUE, character.only = TRUE)
  }
}
# ref: http://stackoverflow.com/questions/26573368/uninstall-remove-r-package-with-dependencies
`_tam_detachPackageWithDepends` <- function(pkg, recursive = FALSE){
  require("tools")
  # get package depencies for all the loaded packages.
  # get installed package matrix
  installedPackages = installed.packages();
  # filter matrix and get only loaded package
  loadedPackages = installedPackages[installedPackages[, "Package"] %in% loadedNamespaces(),]
  # get dependencies for loaded packages
  d <- package_dependencies(,loadedPackages, recursive = recursive)
  # get depdencies for specified package with argument
  depends <- if(!is.null(d[[pkg]])) d[[pkg]] else character()
  needed <- unique(unlist(d[!names(d) %in% c(pkg,depends)]))
  # get TAM required packages (dplyr etc) from option
  tamNeeded <- getOption("tam.required_package_list")
  # only remove packages that are not referenced by other packages and not in TAM required packages list.
  toRemove <- depends[(!depends %in% needed) & (!depends %in% tamNeeded)]
  `_tam_detachPackage`(pkg)
  if(length(toRemove)){
    sapply(toRemove, function(x){
      `_tam_detachPackage`(x)
    })
  }
}

# since head() function drops all the user-defined class info 
# here we have our version of head() command. 
`_tam_head` <- function(x, limit){
  # we need to ungroup the given data frame slice command doensn't limit
  # if the given data frame is in grouped status.
  slice(ungroup(x), 1:limit)
}


# Converts US state names such as 'California' to the corresponding 
# state codes such as 'CA'. If it doesn't match, it returns 
# the original value in upper case.
# TODO: move to exploratory package
`_tam_statecode` <- function(col, ignore.case=T) {
  # state is a part of datasets package which comes with R installation
  # and available anytime. state.abb is a list of state abbreviation
  # such as 'CA' or 'NY'. state.name is a list of state name
  # such as 'California'. 
  # https://stat.ethz.ch/R-manual/R-devel/library/datasets/html/state.html 
  if (ignore.case) {
    return (state.abb[match(tolower(col), tolower(state.name))])
  } else {
    return (state.abb[match(col, state.name)]) #faster
  }
}

# API to create a temporary environment for RDATA staging
`_tam_createTempEnvironment` <- function(){
  new.env(parent = globalenv())
}

# API to get a list of data frames from a RDATA
`_tam_getObjectListFromRdata` <- function(rdata_path, temp.space){
  # load RDATA to temporary env to prevent the polluation on global objects
  temp.object <- load(rdata_path,temp.space)
  # get list of ojbect loaded to temporary env
  objectlist <- ls(envir=temp.space)
  result <- lapply(objectlist, function(x){
    # only get a object whose class is data.frame
    if("data.frame" %in% class(get(x,temp.space))){
      x
    }
  })
  if(!is.null(result) & length(result)>0){
    unlist(result)    
  } else {
    c("");
  }
} 

# API to get a data frame object from RDATA
`_tam_getObjectFromRdata` <- function(rdata_path, object_name){
  # load RDATA to temporary env to prevent the polluation on global objects
  temp.space = `_tam_createTempEnvironment`()
  load(rdata_path,temp.space)
  # get list of ojbect loaded to temporary env
  obj <- get(object_name,temp.space)
  # remote temporary env
  rm(temp.space)
  obj
} 


# Need some return value for rserve client
print('Finish library loading')
