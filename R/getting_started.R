#' --- 
#' title: "Simulation title"
#' output:
#'   html_document:
#'     theme: readable
#'     code_download: true
#' ---


#-------------------------------------------------------------------

library(SimDesign)

Design <- createDesign(factor1 = NA,
                       factor2 = NA)

#-------------------------------------------------------------------

Generate <- function(condition, fixed_objects) {
    dat <- data.frame()
    dat
}

Analyse <- function(condition, dat, fixed_objects) {
    ret <- nc(stat1 = NaN, stat2 = NaN)
    ret
}

Summarise <- function(condition, results, fixed_objects) {
    ret <- c(bias = NaN, RMSE = NaN)
    ret
}

#-------------------------------------------------------------------

res <- runSimulation(design=Design, replications=2, generate=Generate, 
                     analyse=Analyse, summarise=Summarise)
res

