#' @title Simulate data from an unrestricted factor model
#' @description Simulate a common component following the generalised dynamic factor model that does not admit a restricted (static) representation;
#' see the model (C1) in the reference
#' @param n sample size
#' @param p dimension
#' @param q number of unrestricted factors
#' @param heavy if \code{heavy = FALSE}, common shocks are generated from \code{rnorm} whereas if \code{heavy = TRUE}, from \code{rt} with \code{df = 5} and then scaled by \code{sqrt(3 / 5)}
#' @return a list containing
#' \item{data}{ \code{ts} object with \code{n} rows and \code{p} columns }
#' \item{q}{ number of factors}
#' @references Barigozzi, M., Cho, H. & Owens, D. (2024) FNETS: Factor-adjusted network estimation and forecasting for high-dimensional time series. Journal of Business & Economic Statistics (to appear).
#' @references Owens, D., Cho, H. & Barigozzi, M. (2024) fnets: An R Package for Network Estimation and Forecasting via Factor-Adjusted VAR Modelling. The R Journal (to appear).
#' @examples
#' common <- sim.unrestricted(500, 50)
#' @importFrom stats rnorm runif rt as.ts
#' @export
sim.unrestricted <- function(n, p, q = 2, heavy = FALSE) {
  n <- posint(n)
  p <- posint(p)
  q <- posint(q)
  trunc.lags <- min(20, round(n / log(n)))
  chi <- matrix(0, p, n)
  ifelse(!heavy, uu <- matrix(rnorm((n + trunc.lags) * q), ncol = q),
         uu <-matrix(rt((n + trunc.lags) * q, df = 5), ncol = q) * sqrt(3 / 5))

  a <- matrix(runif(p * q,-1, 1), ncol = q)
  alpha <- matrix(runif(p * q,-.8, .8), ncol = q)
  for(ii in 1:p) {
    for(jj in 1:q) {
      coeffs <-
        alpha[ii, jj] * as.numeric(var.to.vma(as.matrix(a[ii, jj]), trunc.lags))
      for(tt in 1:n)
        chi[ii, tt] <-
          chi[ii, tt] + coeffs %*% uu[(tt + trunc.lags):tt, jj, drop = FALSE]
    }
  }
  return(list(data = as.ts(t(chi)), q = q))
}

#' @title Simulate data from a restricted factor model
#' @description Simulate a factor-driven component that admits a restricted (static) representation;
#' see the model (C2) in the reference.
#' @param n sample size
#' @param p dimension
#' @param q number of unrestricted factors; number of restricted factors is given by \code{2 * q}
#' @param heavy if \code{heavy = FALSE}, common shocks are generated from \code{rnorm} whereas if \code{heavy = TRUE}, from \code{rt} with \code{df = 5} and then scaled by \code{sqrt(3 / 5)}
#' @param df if \code{heavy = TRUE}, common shocks are generated from \code{rt} with degrees of freedom given by \code{df}
#' @param lags number of lags of common shocks used in the Factor vector
#' @return a list containing
#' \item{data}{ \code{ts} object with \code{n} rows and \code{p} columns }
#' \item{q}{ number of factors}
#' \item{r}{ number of restricted factors}
#' @references Barigozzi, M., Cho, H. & Owens, D. (2024) FNETS: Factor-adjusted network estimation and forecasting for high-dimensional time series. Journal of Business & Economic Statistics (to appear).
#' @references Owens, D., Cho, H. & Barigozzi, M. (2024) fnets: An R Package for Network Estimation and Forecasting via Factor-Adjusted VAR Modelling. The R Journal (to appear).
#' @examples
#' common <- sim.restricted(500, 50)
#' @importFrom stats rnorm runif rt as.ts
#' @export
sim.restricted <- function(n, p, q = 2, heavy = FALSE, df = 5, lags = 1) {
  n <- posint(n)
  p <- posint(p)
  q <- posint(q)
  lags <- lags
  r <- q * (lags + 1)
  burnin <- 100
  ifelse(!heavy, uu <- matrix(rnorm((n + burnin) * q), nrow = q),
    uu <- matrix(rt((n + burnin) * q, df = df), nrow = q) * sqrt(df-2 / df))
  D0 <- matrix(runif(q^2, 0, .3), nrow = q)
  diag(D0) <- runif(q, .5, .8)
  D <- 0.7 * D0 / norm(D0, type = "2")

  f <- matrix(0, nrow = q, ncol = n + burnin)
  f[, 1] <- uu[, 1]
  for(tt in 2:(n + burnin))
    f[, tt] <- D %*% f[, tt - 1] + uu[, tt]
  f <- f[,-(1:(burnin - lags)), drop = FALSE]

  loadings <- matrix(rnorm(p * r, 0, 1), nrow = p)
  chi <- matrix(0, p, n)
  for(ii in 0:lags)
    chi <- chi + loadings[, ii * q + 1:q, drop = FALSE] %*% f[, 1:n + lags - ii]
  return(list(data = as.ts(t(chi)), q = q, r = r))

}

#' @title Simulate a VAR(1) process
#' @description Simulate a VAR(1) process; see the reference for the generation of the transition matrix.
#' @param n sample size
#' @param p dimension
#' @param Gamma innovation covariance matrix; ignored if \code{heavy = TRUE}
#' @param heavy if \code{heavy = FALSE}, innovation errors are generated from \code{rnorm} whereas if \code{heavy = TRUE}, from \code{rt} with \code{df = 5} and then scaled by \code{sqrt(3 / 5)}
#' @param df if \code{heavy = TRUE}, innovation errors are generated from \code{rt} with degrees of freedom given by \code{df}
#' @return a list containing
#' \item{data}{ \code{ts} object with \code{n} rows and \code{p} columns }
#' \item{A}{ transition matrix}
#' \item{Gamma}{ innovation covariance matrix}
#' @references Barigozzi, M., Cho, H. & Owens, D. (2024) FNETS: Factor-adjusted network estimation and forecasting for high-dimensional time series. Journal of Business & Economic Statistics (to appear).
#' @references Owens, D., Cho, H. & Barigozzi, M. (2024) fnets: An R Package for Network Estimation and Forecasting via Factor-Adjusted VAR Modelling. The R Journal (to appear).
#' @examples
#' idio <- sim.var(500, 50)
#' @importFrom MASS mvrnorm
#' @importFrom stats rnorm rt as.ts
#' @export
sim.var <- function(n,
                    p,
                    Gamma = diag(1, p),
                    heavy = FALSE,
                    df = 5) {
  n <- posint(n)
  p <- posint(p)
  burnin <- 100
  prob <- 1 / p

  ifelse(!heavy,
    ifelse(identical(Gamma, diag(1, p)), xi <- matrix(rnorm((n + burnin) * p), nrow = p),
           xi <- t(MASS::mvrnorm(n + burnin, mu = rep(0, p), Sigma = Gamma))),
    xi <- matrix(rt((n + burnin) * p, df = df), nrow = p) * sqrt(df-2 / df))

  A <- matrix(0, p, p)
  index <- sample(c(0, 1), p^2, TRUE, prob = c(1 - prob, prob))
  A[which(index == 1)] <- .275
  A <- A / norm(A, "2")

  for(tt in 2:(n + burnin))
    xi[, tt] <- xi[, tt] + A %*% xi[, tt - 1]
  xi <- xi[,-(1:burnin)]

  return(list(data = as.ts(t(xi)), A = A, Gamma = Gamma))
}
