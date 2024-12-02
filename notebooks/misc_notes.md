# Notes on SimDesign


- [Working with the SimDesign
  Package](#working-with-the-simdesign-package)
  - [Step 1: Generate a structural template for a
    generate-analyse-summarise
    workflow](#step-1-generate-a-structural-template-for-a-generate-analyse-summarise-workflow)
  - [Step 2: Use `createDesign()` to create a design
    object](#step-2-use-createdesign-to-create-a-design-object)
  - [Step 3: Edit the `Generate`, `Analyse`, and `Summarise`
    functions](#step-3-edit-the-generate-analyse-and-summarise-functions)
  - [Interlude: Figure out the format of the arguments passed to
    Summarise](#interlude-figure-out-the-format-of-the-arguments-passed-to-summarise)
  - [Step 4: Look at the results of the toy
    example](#step-4-look-at-the-results-of-the-toy-example)
- [Minor things that annoy me](#minor-things-that-annoy-me)

Gidon really likes the package so let’s give this a shot.

## Working with the SimDesign Package

``` r
library(SimDesign)
```

### Step 1: Generate a structural template for a generate-analyse-summarise workflow

The first recommendation in the tutorial is to use

``` r
SimDesign::SimFunctions()
```

to generate a template. Let’s save it to a file:

``` r
SimDesign::SimFunctions(file = "R/getting_started.R")
```

Note: this create a double `.R` extension. The package does not check if
you already have an extension in the file name (so don’t add `.R` to the
file name):

``` r
SimDesign::SimFunctions(file = "R/getting_started")
```

The output looks like this:

<div class="code-with-filename">

**R/getting_started.R**

``` r
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
```

</div>

I am not a big fan of the capital letters in the function names but I’ll
deal with that later.

### Step 2: Use `createDesign()` to create a design object

I’m not absolutely sure what a design is in this context, but it sounds
like it might be a grid of parameters? The tutorial recommends using the
following function and then editing the resulting Design object
definition:

``` r
createDesign()
```

I see that this is already present in the `getting_started.R` file.

This looks just like an `expand.grid` wrapped in a tible:

``` r
Design <- createDesign(a = c(1,2,5), b = c(2,5))
Design
```

    # A tibble: 6 × 2
          a     b
      <dbl> <dbl>
    1     1     2
    2     2     2
    3     5     2
    4     1     5
    5     2     5
    6     5     5

The only difference seems to be the presence of an extra attribute
`Design.ID` and that this object is of class `Design`. Is any of this
necesary? I will setup a basic grid for testing the simple 2-parameter
mixture model:

``` r
Design <- createDesign(n = c(20, 50, 100),
                       pmem = c(0.3, 0.6, 0.9),
                       kappa = c(2, 8, 32))
```

### Step 3: Edit the `Generate`, `Analyse`, and `Summarise` functions

I replaced them with functions for generating data from the 2-parameter
mixture model, fitting the model via mixtur, and summarizing the
correlation between the true and estimated parameters:

``` r
library(SimDesign)
library(bmm)
library(mixtur)

Design <- createDesign(
  n = c(20, 50, 100),
  pmem = c(0.3, 0.6, 0.9),
  kappa = c(2, 8, 32)
)

#-------------------------------------------------------------------

Generate <- function(condition, fixed_objects) {
  reponse <- bmm::rmixture2p(
    n = condition$n,
    kappa = condition$kappa,
    p_mem = condition$pmem
  )
  data.frame(response = reponse, target = 0, id = 1)
}

Analyse <- function(condition, dat, fixed_objects) {
  suppressMessages(
    mixtur::fit_mixtur(dat, model = "2_component", unit = "radians") |>
      dplyr::select(kappa, p_t) |>
      dplyr::rename(kappa_est = kappa, pmem_est = p_t)
  )
}

Summarise <- function(condition, results, fixed_objects) {
  list(
    corr = list(
      kappa = cor(condition$kappa, results$kappa_est),
      pmem = cor(condition$pmem, results$pmem_est)
    ),
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

try({
  res <- runSimulation(
    design = Design, replications = 4, generate = Generate,
    analyse = Analyse, summarise = Summarise
  )
})
```



    Design: 1/27;   RAM Used: 185.1 Mb;   Replications: 4;   Total Time: 0.00s 
     Conditions: n=20, pmem=0.3, kappa=2

    Error : Summarise() should not throw errors. Message was:
        Error in cor(condition$kappa, results$kappa_est) : 
      incompatible dimensions

which… gives me an error.

I have misunderstood whne the Summarise function is applied. I thought
it is used on the final results over the entire design grid. But the
real workflow is like this:

![](assets/simdesign-structure.png)

Specifically, for a single row of the design grid, we get as many
results from Analyze() as there are replications. Then Summarise() is
applied to these results. This means that the `condition` object in
Summarise() is a single row of the design grid, and I cannot compute the
correlation between the true and estimated parameters as I did. I will
need to do that **outside** of the runSimulation() call.

### Interlude: Figure out the format of the arguments passed to Summarise

I don’t quite understand what the format of the variables passed to
Summarise is. I added the following two lines to the `Summarise`
function:

``` r
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
res <- runSimulation(
  design = Design, replications = 4, generate = Generate,
  analyse = Analyse, summarise = Summarise, verbose = FALSE
)
```

after running the script, I can inspect the files:

``` r
readRDS('output/condition.rds')
```

    # A tibble: 1 × 4
         ID     n  pmem kappa
      <int> <dbl> <dbl> <dbl>
    1    27   100   0.9    32

Thus the condition input is a tibble with a single row of the Design
object (plus an extra variable ID).

Now the results object. I wasn’t sure what to expect, because the
Analyse functio returns a data.frame with one row. Was I going to get a
list of data.frames? Or a data.frame with multiple rows?

``` r
readRDS('output/results.rds') |> str()
```

    'data.frame':   4 obs. of  2 variables:
     $ kappa_est: num  29.6 33.2 30.7 29.2
     $ pmem_est : num  0.854 0.876 0.934 0.939

A data.frame with multiple rows it is.

What happens if I return a list from Analyse() instead of a data.frame?

``` r
Analyse <- function(condition, dat, fixed_objects) {
  suppressMessages(
    mixtur::fit_mixtur(dat, model = "2_component", unit = "radians") |>
      dplyr::select(kappa, p_t) |>
      dplyr::rename(kappa_est = kappa, pmem_est = p_t)
  ) |> as.list()
} 

res <- runSimulation(
  design = Design, replications = 4, generate = Generate,
  analyse = Analyse, summarise = Summarise, verbose = FALSE
)

readRDS('output/results.rds') |> str()
```

    List of 4
     $ :List of 2
      ..$ kappa_est: num 26.8
      ..$ pmem_est : num 0.982
     $ :List of 2
      ..$ kappa_est: num 29.6
      ..$ pmem_est : num 0.893
     $ :List of 2
      ..$ kappa_est: num 38.7
      ..$ pmem_est : num 0.919
     $ :List of 2
      ..$ kappa_est: num 32.6
      ..$ pmem_est : num 0.916

A cool, it forces the result to be of the same form as the output of
Analyze. This is important and I should remember this.

### Step 4: Look at the results of the toy example

Strange, when I call the resulting object from `runSimulation()` I get a
tibble with some stats, but no results:

``` r
res
```

    # A tibble: 27 × 7
           n  pmem kappa REPLICATIONS SIM_TIME       SEED COMPLETED               
       <dbl> <dbl> <dbl>        <dbl> <chr>         <int> <chr>                   
     1    20   0.3     2            4 0.04s    2016921863 Mon Dec  2 12:42:29 2024
     2    50   0.3     2            4 0.02s    1374640086 Mon Dec  2 12:42:29 2024
     3   100   0.3     2            4 0.03s    1057221823 Mon Dec  2 12:42:29 2024
     4    20   0.6     2            4 0.02s    1984374951 Mon Dec  2 12:42:29 2024
     5    50   0.6     2            4 0.02s     953673063 Mon Dec  2 12:42:29 2024
     6   100   0.6     2            4 0.02s    1733400810 Mon Dec  2 12:42:30 2024
     7    20   0.9     2            4 0.03s    1860787378 Mon Dec  2 12:42:30 2024
     8    50   0.9     2            4 0.02s    1879820661 Mon Dec  2 12:42:30 2024
     9   100   0.9     2            4 0.02s     901099047 Mon Dec  2 12:42:30 2024
    10    20   0.3     8            4 0.02s      27517664 Mon Dec  2 12:42:30 2024
    # ℹ 17 more rows

(PS: I was naughty and tried to get rid of the argument “fixed_objects”
in the functions or to rename it. Alas, this is not allowed even if I
have no use for it. Not a great design choice.)

Seems like something has change between the published tutorial paper
(2020) and the current package version (11-2024), because when I run the
`runSimulation()` function with the verbose option on, I get the
following note:

    Note: To extract Summarise() results use SimExtract(., what = 'summarise')

Ok? Let’s try that:

``` r
extract <- SimExtract(res, what = 'summarise')
str(extract[1:5])
```

    List of 5
     $ n=20 ; pmem=0.3 ; kappa=2 :List of 2
      ..$ bias:List of 2
      .. ..$ kappa: num NaN
      .. ..$ pmem : num NaN
      ..$ rmse:List of 2
      .. ..$ kappa: num NaN
      .. ..$ pmem : num NaN
     $ n=50 ; pmem=0.3 ; kappa=2 :List of 2
      ..$ bias:List of 2
      .. ..$ kappa: num NaN
      .. ..$ pmem : num NaN
      ..$ rmse:List of 2
      .. ..$ kappa: num NaN
      .. ..$ pmem : num NaN
     $ n=100 ; pmem=0.3 ; kappa=2:List of 2
      ..$ bias:List of 2
      .. ..$ kappa: num NaN
      .. ..$ pmem : num NaN
      ..$ rmse:List of 2
      .. ..$ kappa: num NaN
      .. ..$ pmem : num NaN
     $ n=20 ; pmem=0.6 ; kappa=2 :List of 2
      ..$ bias:List of 2
      .. ..$ kappa: num NaN
      .. ..$ pmem : num NaN
      ..$ rmse:List of 2
      .. ..$ kappa: num NaN
      .. ..$ pmem : num NaN
     $ n=50 ; pmem=0.6 ; kappa=2 :List of 2
      ..$ bias:List of 2
      .. ..$ kappa: num NaN
      .. ..$ pmem : num NaN
      ..$ rmse:List of 2
      .. ..$ kappa: num NaN
      .. ..$ pmem : num NaN

A strange format… Oh, is it because I am outputing a list from
Summarise?

``` r
Summarise <- function(condition, results, fixed_objects) {
  data.frame(
    bias_kappa = mean(results$kappa_est - condition$kappa),
    bias_pmem = mean(results$pmem_est - condition$pmem),
    rmse_kappa = sqrt(mean((results$kappa_est - condition$kappa)^2)),
    rmse_pmem = sqrt(mean((results$pmem_est - condition$pmem)^2))
  )
}

res <- runSimulation(
  design = Design, replications = 100, generate = Generate,
  analyse = Analyse, summarise = Summarise, verbose = FALSE,
  parallel = TRUE, ncores = 10,
  save_results = TRUE, save_details = list(save_results_dirname = "output/SimDesign")
)

res
```

    # A tibble: 27 × 11
           n  pmem kappa bias_kappa  bias_pmem rmse_kappa rmse_pmem REPLICATIONS
       <dbl> <dbl> <dbl>      <dbl>      <dbl>      <dbl>     <dbl>        <dbl>
     1    20   0.3     2   12.794    0.18743     62.159    0.40664           100
     2    50   0.3     2    6.5307   0.17631     37.762    0.38792           100
     3   100   0.3     2    0.80887  0.20429      4.2227   0.38176           100
     4    20   0.6     2  145.54     0.09367   1392.9      0.28355           100
     5    50   0.6     2    0.44318  0.08764      2.4085   0.24050           100
     6   100   0.6     2    0.29618  0.027360     1.2214   0.16118           100
     7    20   0.9     2    5.2460   0.0032100   45.115    0.16174           100
     8    50   0.9     2    0.27462  0.0024700    0.85246  0.11079           100
     9   100   0.9     2    0.08538 -0.012500     0.54110  0.092728          100
    10    20   0.3     8    5.2240   0.10191     28.524    0.27314           100
    # ℹ 17 more rows
    # ℹ 3 more variables: SIM_TIME <chr>, SEED <int>, COMPLETED <chr>

Yes, that was it. When I output a data.frame with a single row I get the
results embeded. Wasn’t this supposed to *not* rerun the simulation when
I save the results? Hmm.

Ah, I just misunderstood the manual. The results are saved, but
`runSimulation` runs anyway. I can use `reSummarise` to recompute the
summaries from the saved results.

First, let’s see what I can extract from the existing object. The bias
and rmse single values are fine, but I wanted to see correlation across
the design grid or perhaps plot the results.

I should be able to use `SimExtract` to get the results from the `res`
object:

``` r
SimExtract(res, what = 'results')
```

    NULL

Nothing?

Let’s look at what is saved in the output directory:

``` r
list.files("output/SimDesign")
```

     [1] "results-row-1.rds"  "results-row-10.rds" "results-row-11.rds"
     [4] "results-row-12.rds" "results-row-13.rds" "results-row-14.rds"
     [7] "results-row-15.rds" "results-row-16.rds" "results-row-17.rds"
    [10] "results-row-18.rds" "results-row-19.rds" "results-row-2.rds" 
    [13] "results-row-20.rds" "results-row-21.rds" "results-row-22.rds"
    [16] "results-row-23.rds" "results-row-24.rds" "results-row-25.rds"
    [19] "results-row-26.rds" "results-row-27.rds" "results-row-3.rds" 
    [22] "results-row-4.rds"  "results-row-5.rds"  "results-row-6.rds" 
    [25] "results-row-7.rds"  "results-row-8.rds"  "results-row-9.rds" 

Ok, so I have a bunch of `.rds` files. I can load them and see what’s
inside:

``` r
readRDS(list.files("output/SimDesign", full.names = TRUE)[1]) |> str()
```

    List of 6
     $ condition    : tibble [1 × 3] (S3: tbl_df/tbl/data.frame)
      ..$ n    : num 20
      ..$ pmem : num 0.3
      ..$ kappa: num 2
     $ results      :'data.frame':  100 obs. of  2 variables:
      ..$ kappa_est: num [1:100] 3.93 3.31 14.83 1.14 0 ...
      ..$ pmem_est : num [1:100] 0.487 0.28 0.097 1 0 0.352 0.485 0.621 0.266 0.219 ...
     $ errors       : 'table' int[0 (1d)] 
      ..- attr(*, "dimnames")=List of 1
      .. ..$ : NULL
     $ error_seeds  : NULL
     $ warnings     : 'table' int[0 (1d)] 
      ..- attr(*, "dimnames")=List of 1
      .. ..$ warnings: NULL
     $ warning_seeds: NULL

Ok, that’s what I wanted, I have the results for each replicatation
stored in a data.frame `results`, and one `.rds` file for each row of
the design grid.

Oh, it’s actually a different command, `SimResults`:

``` r
str(SimResults(res)[1:3])
```

    List of 3
     $ :List of 6
      ..$ condition    : tibble [1 × 3] (S3: tbl_df/tbl/data.frame)
      .. ..$ n    : num 20
      .. ..$ pmem : num 0.3
      .. ..$ kappa: num 2
      ..$ results      :'data.frame':   100 obs. of  2 variables:
      .. ..$ kappa_est: num [1:100] 0.452 2.321 4.16 1.209 0.426 ...
      .. ..$ pmem_est : num [1:100] 1 0.577 0.348 1 1 0.64 0.576 0.349 0.387 1 ...
      ..$ errors       : 'table' int[0 (1d)] 
      .. ..- attr(*, "dimnames")=List of 1
      .. .. ..$ : NULL
      ..$ error_seeds  : NULL
      ..$ warnings     : 'table' int[0 (1d)] 
      .. ..- attr(*, "dimnames")=List of 1
      .. .. ..$ warnings: NULL
      ..$ warning_seeds: NULL
     $ :List of 6
      ..$ condition    : tibble [1 × 3] (S3: tbl_df/tbl/data.frame)
      .. ..$ n    : num 50
      .. ..$ pmem : num 0.3
      .. ..$ kappa: num 2
      ..$ results      :'data.frame':   100 obs. of  2 variables:
      .. ..$ kappa_est: num [1:100] 2.03 1.923 3.176 0.338 0.301 ...
      .. ..$ pmem_est : num [1:100] 0.318 0.431 0.258 1 0.616 0.188 1 1 0.356 1 ...
      ..$ errors       : 'table' int[0 (1d)] 
      .. ..- attr(*, "dimnames")=List of 1
      .. .. ..$ : NULL
      ..$ error_seeds  : NULL
      ..$ warnings     : 'table' int[0 (1d)] 
      .. ..- attr(*, "dimnames")=List of 1
      .. .. ..$ warnings: NULL
      ..$ warning_seeds: NULL
     $ :List of 6
      ..$ condition    : tibble [1 × 3] (S3: tbl_df/tbl/data.frame)
      .. ..$ n    : num 100
      .. ..$ pmem : num 0.3
      .. ..$ kappa: num 2
      ..$ results      :'data.frame':   100 obs. of  2 variables:
      .. ..$ kappa_est: num [1:100] 5.483 0.683 5.742 0.572 0.293 ...
      .. ..$ pmem_est : num [1:100] 0.128 0.807 0.246 1 1 0.498 0.344 0.196 1 1 ...
      ..$ errors       : 'table' int[0 (1d)] 
      .. ..- attr(*, "dimnames")=List of 1
      .. .. ..$ : NULL
      ..$ error_seeds  : NULL
      ..$ warnings     : 'table' int[0 (1d)] 
      .. ..- attr(*, "dimnames")=List of 1
      .. .. ..$ warnings: NULL
      ..$ warning_seeds: NULL

Although I have to wonder why this is in a list. Perhaps to save disk
space. Although in [the
tutorial](https://philchalmers.github.io/SimDesign/articles/SimDesign-intro.html)
it just gives a data.frame.

*Note to self:* the reason why `SimExtract` didn’t work and I needed to
use `SimResults` is because I set the “save_results” argument to true.
By default `store_results` is TRUE, meaning that the results are stored
in the returned object and can be extracted. If `save_results` is set to
TRUE, the results are saved to disk and not stored in the returned
object.

Is there a command to aggregate the results, or do I need to write a
function myself?

Before I go down that way, let me first replicate the example from the
website:

``` r
tutorial_design <- createDesign(
  sample_size = c(30, 60, 120, 240),
  distribution = c("norm", "chi")
)

tutorial_generate <- function(condition, fixed_objects) {
  N <- condition$sample_size
  dist <- condition$distribution
  if (dist == "norm") {
    dat <- rnorm(N, mean = 3)
  } else if (dist == "chi") {
    dat <- rchisq(N, df = 3)
  }
  dat
}

tutorial_analyse <- function(condition, dat, fixed_objects) {
  M0 <- mean(dat)
  M1 <- mean(dat, trim = .1)
  M2 <- mean(dat, trim = .2)
  med <- median(dat)

  ret <- c(mean_no_trim = M0, mean_trim.1 = M1, mean_trim.2 = M2, median = med)
  ret
}

tutorial_summarise <- function(condition, results, fixed_objects) {
  obs_bias <- bias(results, parameter = 3)
  obs_RMSE <- RMSE(results, parameter = 3)
  ret <- c(bias = obs_bias, RMSE = obs_RMSE, RE = RE(obs_RMSE))
  ret
}

tutorial_res <- runSimulation(tutorial_design,
  replications = 1000, generate = tutorial_generate,
  analyse = tutorial_analyse, summarise = tutorial_summarise,
  verbose = FALSE
)

tutorial_res
```

    # A tibble: 8 × 18
      sample_size distribution bias.mean_no_trim bias.mean_trim.1 bias.mean_trim.2
            <dbl> <chr>                    <dbl>            <dbl>            <dbl>
    1          30 norm                0.0037577         0.0039147        0.0038303
    2          60 norm               -0.0065965        -0.0059040       -0.0059581
    3         120 norm               -0.0025617        -0.0034006       -0.0043118
    4         240 norm               -0.0012705        -0.0017281       -0.0022920
    5          30 chi                -0.0090061        -0.32472         -0.46413  
    6          60 chi                -0.0084831        -0.34004         -0.48308  
    7         120 chi                 0.0099143        -0.33491         -0.47883  
    8         240 chi                 0.00044196       -0.34833         -0.49341  
    # ℹ 13 more variables: bias.median <dbl>, RMSE.mean_no_trim <dbl>,
    #   RMSE.mean_trim.1 <dbl>, RMSE.mean_trim.2 <dbl>, RMSE.median <dbl>,
    #   RE.mean_no_trim <dbl>, RE.mean_trim.1 <dbl>, RE.mean_trim.2 <dbl>,
    #   RE.median <dbl>, REPLICATIONS <dbl>, SIM_TIME <chr>, SEED <int>,
    #   COMPLETED <chr>

and the results are:

``` r
SimResults(tutorial_res)
```

    # A tibble: 8,000 × 6
       sample_size distribution mean_no_trim mean_trim.1 mean_trim.2 median
             <dbl> <chr>               <dbl>       <dbl>       <dbl>  <dbl>
     1          30 norm                 3.05        3.03        3.03   3.11
     2          30 norm                 3.08        3.00        2.91   2.89
     3          30 norm                 3.00        3.01        3.00   3.04
     4          30 norm                 2.88        2.92        2.91   2.99
     5          30 norm                 2.67        2.57        2.54   2.76
     6          30 norm                 2.83        2.87        2.83   2.72
     7          30 norm                 3.01        2.97        2.94   2.94
     8          30 norm                 2.97        2.96        2.98   3.08
     9          30 norm                 3.28        3.37        3.42   3.35
    10          30 norm                 3.05        3.10        3.10   3.00
    # ℹ 7,990 more rows

Ugh! So why are these aggregated but mine are not? Because these return
a named vector and I return a data.frame? Let’s try that:

``` r
Analyse <- function(condition, dat, fixed_objects) {
  suppressMessages(
    mixtur::fit_mixtur(dat, model = "2_component", unit = "radians") |>
      dplyr::select(kappa, p_t) |>
      dplyr::rename(kappa_est = kappa, pmem_est = p_t) |>
      unlist() # since the data.frame is just one row, this should give a named numeric vector
  )
}

Summarise <- function(condition, results, fixed_objects) {
  data.frame(
    bias_kappa = mean(results$kappa_est - condition$kappa),
    bias_pmem = mean(results$pmem_est - condition$pmem),
    rmse_kappa = sqrt(mean((results$kappa_est - condition$kappa)^2)),
    rmse_pmem = sqrt(mean((results$pmem_est - condition$pmem)^2))
  )
}

res <- runSimulation(
  design = Design, replications = 10, generate = Generate,
  analyse = Analyse, summarise = Summarise, verbose = FALSE,
  save_results = TRUE, save_details = list(save_results_dirname = "output/SimDesign")
)

SimResults(res)[1:3]
```

    [[1]]
    [[1]]$condition
    # A tibble: 1 × 3
          n  pmem kappa
      <dbl> <dbl> <dbl>
    1    20   0.3     2

    [[1]]$results
       kappa_est pmem_est
    1      2.544    0.312
    2      0.952    1.000
    3     23.766    0.251
    4      0.794    1.000
    5      1.436    0.738
    6      0.936    0.448
    7      1.223    1.000
    8     11.500    0.272
    9      0.333    1.000
    10     3.860    0.395

    [[1]]$errors
    < table of extent 0 >

    [[1]]$error_seeds
    NULL

    [[1]]$warnings
    < table of extent 0 >

    [[1]]$warning_seeds
    NULL


    [[2]]
    [[2]]$condition
    # A tibble: 1 × 3
          n  pmem kappa
      <dbl> <dbl> <dbl>
    1    50   0.3     2

    [[2]]$results
       kappa_est pmem_est
    1      0.405    1.000
    2      3.851    0.323
    3      0.618    1.000
    4      0.317    1.000
    5      1.940    0.431
    6      0.479    1.000
    7      1.757    0.540
    8      1.884    0.473
    9     10.832    0.175
    10     0.410    1.000

    [[2]]$errors
    < table of extent 0 >

    [[2]]$error_seeds
    NULL

    [[2]]$warnings
    < table of extent 0 >

    [[2]]$warning_seeds
    NULL


    [[3]]
    [[3]]$condition
    # A tibble: 1 × 3
          n  pmem kappa
      <dbl> <dbl> <dbl>
    1   100   0.3     2

    [[3]]$results
       kappa_est pmem_est
    1      1.741    0.409
    2      2.374    0.366
    3      1.693    0.213
    4      0.525    0.905
    5      2.507    0.416
    6      2.264    0.423
    7      1.364    0.461
    8      0.416    1.000
    9      1.140    0.783
    10     1.712    0.344

    [[3]]$errors
    < table of extent 0 >

    [[3]]$error_seeds
    NULL

    [[3]]$warnings
    < table of extent 0 >

    [[3]]$warning_seeds
    NULL

Hmm, no difference again. Can it be because I am using “save_results”,
instead of “store_results”? Let’s try that:

``` r
res <- runSimulation(
  design = Design, replications = 10, generate = Generate,
  analyse = Analyse, summarise = Summarise, verbose = FALSE,
)

SimResults(res)
```

    # A tibble: 270 × 5
           n  pmem kappa kappa_est pmem_est
       <dbl> <dbl> <dbl>     <dbl>    <dbl>
     1    20   0.3     2      7.38    0.129
     2    20   0.3     2      0       0    
     3    20   0.3     2      0       0    
     4    20   0.3     2      3.18    0.403
     5    20   0.3     2    111.      0.274
     6    20   0.3     2      3.00    0.359
     7    20   0.3     2      4.18    0.395
     8    20   0.3     2      2.36    0.347
     9    20   0.3     2      4.74    0.396
    10    20   0.3     2      1.78    0.571
    # ℹ 260 more rows

Ah, bingo! Ok, the output format of SimResults should not depend on
options set in the `runSimulation` function. I [opened an issue on
GitHub](https://github.com/philchalmers/SimDesign/issues/45).

## Minor things that annoy me

Should this section exist? Probably not. But there are a few minor
things that just bug me for no good reason:

1.  Not a fan of CamelCase function names, but I can live with that.
2.  The `runSimulation` function at minimum takes the following
    arguments, and it annoys me that the numeric argument `replications`
    is in the middle of other arguments

``` r
runSimulation(
  design = Design, 
  replications = 100, 
  generate = Generate,
  analyse = Analyse, 
  summarise = Summarise,
)
```

I know I can change the order of the arguments since they are named, but
I prefer to keep the order of the arguments as they are in the
documentation. I would have liked it more if replications was either the
first argument, or if it followed the `summarise` argument.

3.  The the computation functions require a “fixed_objects” argument
    even if they don’t use it. The package backend should be handling
    this, not the user.
