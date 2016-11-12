#
# TODO: Check out the location of this file at the production build
#

# TODO: evaluate detaching datasets package
# To prevent unwanted objects show up in candidates for
# auto complete, unload datasets packages from session.
# detach(package:datasets)

#' @importFrom lubridate is.difftime is.duration is.interval is.Date is.POSIXt is.POSIXct is.POSIXlt interval time_length
#' @importFrom stringr str_length
NULL

# Return dataframe summary info
# @param x dataframe
get_data_frame_summary = function(x) {
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
    # We use fixed number (12) as breaks as opposed to time-unit like "month",
    # so that we can avoid the case like 15 months period is broken
    # into 12 one-month-length buckets and
    # 3 months worth of data points wrapping around.
    #
    # Note that we need mid values for chart rendering.
    sapply(x, function(x) {
      # Exclude the case if all the data is NA - hist() will complain that case.
      if (all(is.na(x)) == FALSE) {
        if (is.integer(x)) {
          if ((max(x, na.rm = TRUE) - min(x, na.rm = TRUE)) < 40) {
           .a <- hist(x, breaks = (min(x, na.rm = TRUE) - 0.5):(max(x, na.rm = TRUE) + 0.5), plot = FALSE);
           return (list(.a$breaks, .a$counts, .a$mids, 0))
          } else {
           .a <- hist(x, plot=FALSE);
           return (list(.a$breaks, .a$counts, .a$mids, 0))
          }
        } else if (is.numeric(x)){   # number types, duration, period, interval
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
          fmtstr <- get_date_format_string(as.POSIXct(head(.a$breaks, n=1),origin="1970-01-01") , as.POSIXct(tail(.a$breaks, n=1),origin="1970-01-01"))
          .a$breaksdate <-  format(as.POSIXct(.a$breaks, origin="1970-01-01"), fmtstr);
          return (list(.a$breaksdate, .a$counts, .a$mids, c(12), fmtstr))
        } else if (is.POSIXlt(x)) {
          .a<- hist(x, plot=FALSE, breaks=12);
          fmtstr <- get_date_format_string(as.POSIXlt(head(.a$breaks, n=1),origin="1970-01-01"), as.POSIXlt(tail(.a$breaks, n=1),origin="1970-01-01"))
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

# Returns appropriate date format string
get_date_format_string <- function(mindate, maxdate) {
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
