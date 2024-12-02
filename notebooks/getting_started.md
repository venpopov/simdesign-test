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
     $ kappa_est: num  32.9 42.4 32.9 30.1
     $ pmem_est : num  0.886 0.856 0.952 0.927

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
      ..$ kappa_est: num 23
      ..$ pmem_est : num 0.843
     $ :List of 2
      ..$ kappa_est: num 23.2
      ..$ pmem_est : num 0.93
     $ :List of 2
      ..$ kappa_est: num 30.2
      ..$ pmem_est : num 0.878
     $ :List of 2
      ..$ kappa_est: num 37.8
      ..$ pmem_est : num 0.941

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
     1    20   0.3     2            4 0.02s    1697164363 Mon Dec  2 12:47:20 2024
     2    50   0.3     2            4 0.02s    1552967362 Mon Dec  2 12:47:20 2024
     3   100   0.3     2            4 0.03s    2118188717 Mon Dec  2 12:47:20 2024
     4    20   0.6     2            4 0.02s    2072642104 Mon Dec  2 12:47:20 2024
     5    50   0.6     2            4 0.02s    1258856439 Mon Dec  2 12:47:20 2024
     6   100   0.6     2            4 0.02s    1651008935 Mon Dec  2 12:47:20 2024
     7    20   0.9     2            4 0.03s    1348069160 Mon Dec  2 12:47:20 2024
     8    50   0.9     2            4 0.02s    1081097633 Mon Dec  2 12:47:20 2024
     9   100   0.9     2            4 0.02s    1716875653 Mon Dec  2 12:47:20 2024
    10    20   0.3     8            4 0.02s    2025617480 Mon Dec  2 12:47:20 2024
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
     1    20   0.3     2  381.59     0.2511    3720.0      0.44018           100
     2    50   0.3     2   50.418    0.18631    342.14     0.39383           100
     3   100   0.3     2    7.1002   0.14614     49.018    0.32880           100
     4    20   0.6     2    1.8454   0.11249      8.5142   0.27691           100
     5    50   0.6     2    0.96463  0.07346      5.7034   0.24722           100
     6   100   0.6     2    0.39601  0.030500     1.3874   0.17836           100
     7    20   0.9     2    2.1102  -0.0027400   14.638    0.13676           100
     8    50   0.9     2    0.25489  0.0025300    0.84006  0.099106          100
     9   100   0.9     2    0.21434  0.0022700    0.60814  0.090253          100
    10    20   0.3     8    9.6771   0.12049     52.535    0.29305           100
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
      .. ..$ kappa_est: num [1:100] 3.72e+04 6.80e-02 6.84e-01 1.67 1.77 ...
      .. ..$ pmem_est : num [1:100] 0.047 1 1 0.506 0.431 0.51 0.159 0 0.08 1 ...
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
      .. ..$ kappa_est: num [1:100] 0.962 5.378 160.279 1.591 52.651 ...
      .. ..$ pmem_est : num [1:100] 0.265 0.364 0.143 0.515 0.125 0.154 1 0.441 0.145 1 ...
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
      .. ..$ kappa_est: num [1:100] 2.496 3.99 2.597 2.847 0.554 ...
      .. ..$ pmem_est : num [1:100] 0.273 0.293 0.12 0.395 1 0.236 0.266 1 0.084 0.589 ...
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
    1          30 norm                0.010238         0.0091692        0.010167  
    2          60 norm                0.0047822        0.0061445        0.0066667 
    3         120 norm                0.00094017       0.00035580       0.00023621
    4         240 norm                0.0031717        0.0027267        0.0026603 
    5          30 chi                -0.0055570       -0.32959         -0.47009   
    6          60 chi                 0.0016789       -0.33257         -0.47616   
    7         120 chi                -0.0084169       -0.35169         -0.49452   
    8         240 chi                -0.0018711       -0.34883         -0.49080   
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
     1          30 norm                 2.69        2.70        2.70   2.75
     2          30 norm                 2.86        2.86        2.85   2.95
     3          30 norm                 3.01        2.97        3.00   3.05
     4          30 norm                 2.95        2.97        2.94   2.74
     5          30 norm                 2.85        2.84        2.81   2.67
     6          30 norm                 2.91        2.99        3.00   3.11
     7          30 norm                 3.03        3.08        3.10   3.29
     8          30 norm                 3.20        3.15        3.14   3.22
     9          30 norm                 2.87        2.88        2.90   2.88
    10          30 norm                 2.87        2.94        2.95   2.90
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
    1    256.615    0.112
    2      2.048    0.398
    3      0.073    1.000
    4     21.471    0.249
    5      1.042    0.819
    6      3.660    0.418
    7      2.527    0.450
    8     12.888    0.258
    9      0.216    1.000
    10     2.874    0.534

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
    1     10.450    0.140
    2      0.467    1.000
    3      0.689    1.000
    4      4.966    0.314
    5      1.651    0.401
    6      3.101    0.278
    7      1.557    0.760
    8      0.194    1.000
    9      0.420    1.000
    10     0.285    0.999

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
    1      0.894    0.543
    2      2.432    0.245
    3      4.524    0.267
    4      1.511    0.374
    5      2.711    0.348
    6      8.611    0.182
    7      2.254    0.293
    8      1.206    0.360
    9      3.052    0.378
    10     6.571    0.224

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
     1    20   0.3     2     0.592    1    
     2    20   0.3     2    13.8      0.287
     3    20   0.3     2     0.809    0.631
     4    20   0.3     2     0.73     1    
     5    20   0.3     2    12.3      0.289
     6    20   0.3     2   391.       0.119
     7    20   0.3     2    39.0      0.114
     8    20   0.3     2     2.79     0.309
     9    20   0.3     2     2.58     0.546
    10    20   0.3     2     0.016    0.998
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
