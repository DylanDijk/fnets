% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/idio.R
\name{fnets.glmnet}
\alias{fnets.glmnet}
\title{Implementing cv.glmnet for VAR estimation}
\usage{
fnets.glmnet(
  xx,
  lambda = NULL,
  var.order = 1,
  tuning.args = list(tuning = c("cv", "bic"), n.folds = 1, penalty = NULL, path.length =
    10),
  n.cores = 1,
  q = q
)
}
\description{
Implementing cv.glmnet for VAR estimation
}
\keyword{internal}
