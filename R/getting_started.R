# be sure to use remotes::install_github("venpopov/mixtur") for vastly improve efficiency
library(SimDesign)
library(bmm)
library(mixtur) 

Design <- createDesign(n = c(20, 50, 100),
                       pmem = c(0.3, 0.6, 0.9),
                       kappa = c(2, 8, 32))

#-------------------------------------------------------------------

Generate <- function(condition, fixed_objects) {
    data.frame(
      response = bmm::rmixture2p(
        n = condition$n, 
        kappa = condition$kappa, 
        p_mem = condition$pmem
      ),
      target = 0,
      id = 1
    )
}

Analyse <- function(condition, dat, fixed_objects) {
  suppressMessages(
    mixtur::fit_mixtur(dat, model = "2_component", unit = "radians") |> 
      dplyr::select(kappa, p_t) |> 
      dplyr::rename(kappa_est = kappa, pmem_est = p_t)
  )
}

Summarise <- function(condition, results, fixed_objects) {
    saveRDS(results, "output/results.rds")
    saveRDS(condition, "output/condition.rds")
    list(
      bias = list(
        kappa = mean(results$kappa_est - condition$kappa),
        pmem = mean(results$pmem_est - condition$pmem)
      ),
      rmse = list(
        kappa = sqrt(mean((results$kappa_est - condition$kappa)^2)),
        pmem = sqrt(mean((results$pmem_est - condition$pmem)^2))
      )
    )
}

#-------------------------------------------------------------------

res <- runSimulation(
  design = Design, replications = 2, generate = Generate,
  analyse = Analyse, summarise = Summarise
)
                     

res
