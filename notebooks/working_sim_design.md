# A working example


In ![Getting started](getting_started.qmd) I expored the initial stages
of using SimDesign and ran into some issues. Starting here fresh after I
have cleared some of those issues up

``` r
# be sure to use remotes::install_github("venpopov/mixtur") instead of the CRAN version for vastly improved efficiency
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

if (!dir.exists("output")) dir.create("output")
out_file <- "output/m2p_sim_design_res.rds"

if (file.exists(out_file)) {
  res <- readRDS(out_file)
} else {
  res <- runSimulation(
    design = par_grid,
    generate = m2p_generate,
    analyse = m2p_analyze,
    replications = 100,
    parallel = TRUE, ncores = 10
  )
  saveRDS(res, out_file)
}
```
