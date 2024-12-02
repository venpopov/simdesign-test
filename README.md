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
