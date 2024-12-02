This repository is aimed at myself. My goal is to explore how the R SimDesign package might be useful for me in doing parameter recovery simulations. I also want to learn how it might be integrated into my existing tech stack and workflow.

## Log

### Standard R Project Setup

Create local repository

```bash
mkdir repos/simdesign-test
cd repos/simdesign-test
git init
```

Create and push to remote repository via CLI

```bash
gh repo create
```

(follow terminal prompts)

Add README.md

```bash
touch README.md
```

(add initial Readme content)

Create an initial commit

```bash
git add .
git commit -m "Initial commit"
git push
```

Initialize `renv` 

```r
renv::init()
q()
```

Adapt `.Rprofile` to deal with VS Code better (creates RENV settings I like and makes sure to load my user `.Rprofile` before the project `.Rprofile`; this is necessary because VS Code requires some extra settings and packages to work well with R):

```bash
echo '
Sys.setenv(
  RENV_CONFIG_RSPM_ENABLED = FALSE,
  RENV_CONFIG_SANDBOX_ENABLED = FALSE
)

if (requireNamespace("rprofile", quietly = TRUE)) {
  rprofile::load(dev = quote(reload()))
} else {
  source("renv/activate.R")
}
' > .Rprofile
```

followed by 

```
renv::snapshot()
```

### Working with the SimDesign Package

The first recommendation in the tutorial is to use 

```r
SimDesign::SimFunctions()
```

to generate a template. Let's save it to a file:

```r
SimDesign::SimFunctions(file = "R/getting_started.R")
```

Note: this create a double `.R` extension. The package does not check if you already have an extension in the file name (so don't add `.R` to the file name):

```r
SimDesign::SimFunctions(file = "R/getting_started")
```

The output looks like this:

```r
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

```

I am not a big fan of the capital letters in the function names. 
