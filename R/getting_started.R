# be sure to use remotes::install_github("venpopov/mixtur") for vastly improve efficiency
library(SimDesign)
library(bmm)
library(mixtur) 

m2p_generate <- function(condition, fixed_objects) {
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

m2p_analyze <- function(condition, dat, fixed_objects) {
  suppressMessages(
    mixtur::fit_mixtur(dat, model = "2_component", unit = "radians") |> 
      dplyr::select(kappa, p_t) |> 
      dplyr::rename(kappa_est = kappa, pmem_est = p_t)
  )
}


par_grid <- expand.grid(
  n = c(20, 50, 100),
  pmem = c(0.3, 0.6, 0.9),
  kappa = c(2, 8, 32)
)

res <- runSimulation(
  design = par_grid,
  generate = m2p_generate,
  analyse = m2p_analyze,
  replications = 100,
  parallel = TRUE, ncores = 10
)
                    

