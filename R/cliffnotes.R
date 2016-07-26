#' cliffnotes
#'
#' data summaries and analysis
#'
#' @import htmlwidgets
#'
#' @export
cliffnotes <- function(df, width = NULL, height = NULL) {
  params <- list(data = get_data_frame_summary(df))
  attr(params, 'TOJSON_ARGS') <- list(auto_unbox = FALSE, keep_vec_names=FALSE)

  # create widget
  htmlwidgets::createWidget(
    name = 'cliffnotes',
    x = params,
    width = width,
    height = height,
    package = 'cliffnotes'
  )
}

#' Shiny bindings for cliffnotes
#'
#' Output and render functions for using cliffnotes within Shiny
#' applications and interactive Rmd documents.
#'
#' @param outputId output variable to read from
#' @param width,height Must be a valid CSS unit (like \code{'100\%'},
#'   \code{'400px'}, \code{'auto'}) or a number, which will be coerced to a
#'   string and have \code{'px'} appended.
#' @param expr An expression that generates a cliffnotes
#' @param env The environment in which to evaluate \code{expr}.
#' @param quoted Is \code{expr} a quoted expression (with \code{quote()})? This
#'   is useful if you want to save an expression in a variable.
#'
#' @name cliffnotes-shiny
#'
#' @export
cliffnotesOutput <- function(outputId, width = '100%', height = '400px'){
  htmlwidgets::shinyWidgetOutput(outputId, 'cliffnotes', width, height, package = 'cliffnotes')
}

#' @rdname cliffnotes-shiny
#' @export
renderCliffnotes <- function(expr, env = parent.frame(), quoted = FALSE) {
  if (!quoted) { expr <- substitute(expr) } # force quoted
  htmlwidgets::shinyRenderWidget(expr, cliffnotesOutput, env, quoted = TRUE)
}

