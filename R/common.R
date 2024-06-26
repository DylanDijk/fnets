#' @title Forecasting the factor-driven common component
#' @description Produces forecasts of the common component
#' for a given forecasting horizon by estimating the best linear predictors
#' @param object \code{fnets} object
#' @param x input time series matrix, with each row representing a variable
#' @param n.ahead forecasting horizon
#' @param fc.restricted whether to forecast using a restricted or unrestricted, blockwise VAR representation of the common component
#' @param r number of restricted factors, or a string specifying the factor number selection method when \code{fc.restricted = TRUE};
#'  possible values are:
#' \describe{
#'    \item{\code{"ic"}}{ information criteria of Alessi, Barigozzi & Capasso (2010))}
#'    \item{\code{"er"}}{ eigenvalue ratio of Ahn & Horenstein (2013)}
#' }
#' @return a list containing
#' \item{is}{ in-sample estimator of the common component (with each column representing a variable)}
#' \item{fc}{ forecasts of the common component for a given forecasting horizon \code{h} (with each column representing a variable)}
#' \item{r}{ restricted factor number}
#' \item{n.ahead}{ forecast horizon}
#' @references Ahn, S. C. & Horenstein, A. R. (2013) Eigenvalue ratio test for the number of factors. Econometrica, 81(3), 1203--1227.
#' @references Alessi, L., Barigozzi, M., and Capasso, M. (2010) Improved penalization for determining the number of factors in approximate factor models. Statistics & Probability Letters, 80(23-24):1806–1813.
#' @references Barigozzi, M., Cho, H. & Owens, D. (2024) FNETS: Factor-adjusted network estimation and forecasting for high-dimensional time series. Journal of Business & Economic Statistics (to appear).
#' @references Forni, M., Hallin, M., Lippi, M. & Reichlin, L. (2005) The generalized dynamic factor model: one-sided estimation and forecasting. Journal of the American Statistical Association, 100(471), 830--840.
#' @references Forni, M., Hallin, M., Lippi, M. & Zaffaroni, P. (2017) Dynamic factor models with infinite-dimensional factor space: Asymptotic analysis. Journal of Econometrics, 199(1), 74--92.
#' @references Owens, D., Cho, H. & Barigozzi, M. (2024) fnets: An R Package for Network Estimation and Forecasting via Factor-Adjusted VAR Modelling. The R Journal (to appear).
#' @examples
#' \dontrun{
#' out <- fnets(data.unrestricted, q = NULL, var.order = 1, var.method = "lasso",
#' do.lrpc = FALSE, var.args = list(n.cores = 2))
#' cpre <- common.predict(out)
#' ipre <- idio.predict(out, cpre)
#' }
#' @keywords internal
common.predict <-
  function(object,
           x,
           n.ahead = 1,
           fc.restricted = TRUE,
           r = c("ic", "er")) {
    xx <- x - object$mean.x
    p <- dim(x)[1]

    if(!is.numeric(r)) {
      r.method <- match.arg(r, c("ic", "er"))
      r <- NULL
    } else
      r.method <- NULL

    pre <- list(is = 0 * t(x), fc = matrix(0, nrow = n.ahead, ncol = p))
    if(attr(object, "factor") == "unrestricted") {
      if(object$q < 1) {
        warning(
          "There should be at least one factor for common component estimation!"
        )
      } else {
        if(fc.restricted)
          pre <-
            common.restricted.predict(
              xx = xx,
              Gamma_x = object$acv$Gamma_x,
              Gamma_c = object$acv$Gamma_c,
              q = object$q,
              r = r,
              r.method = r.method,
              n.ahead = n.ahead
            )
        else
          pre <-
            common.unrestricted.predict(xx = xx,
                                        cve = object,
                                        n.ahead = n.ahead)
      }
    }

    if(attr(object, "factor") == "restricted") {
      if(object$q < 1) {
        warning("There should be at least one factor for common component estimation!")
      } else if(object$q >= 1) {
      if(!fc.restricted)
        warning("fc.restricted is being set to TRUE, as fnets object is generated with fm.restricted = TRUE")
      pre <-
        common.restricted.predict(
          xx = xx,
          Gamma_x = object$acv$Gamma_x,
          Gamma_c = object$acv$Gamma_c,
          q = object$q,
          r = object$q,
          r.method = r.method,
          n.ahead = n.ahead
        )

      }
    }
    return(pre)
  }

#' @title Blockwise VAR estimation under GDFM
#' @keywords internal
common.irf.estimation <-
  function(xx,
           Gamma_c,
           q,
           factor.var.order = NULL,
           max.var.order = NULL,
           trunc.lags,
           n.perm) {
    n <- dim(xx)[2]
    p <- dim(xx)[1]
    mm <- (dim(Gamma_c)[3] - 1) / 2
    N <- p %/% (q + 1)
    if(!is.null(factor.var.order))
      max.var.order <- factor.var.order
    if(is.null(max.var.order))
      max.var.order <-
      min(factor.var.order, max(1, ceiling(10 * log(n, 10) / (q + 1) ^ 2)), 10)

    if(q < 1){
      warning("There should be at least one factor for common component estimation!")
    } else {
      # for each permutation, obtain IRF and u (with cholesky identification), average the output, what FHLZ 2017 do
      irf.array <- array(0, dim = c(p, q, trunc.lags + 2, n.perm))
      u.array <- array(0, dim = c(q, n, n.perm))

      for (ii in 1:n.perm) {
        ifelse(ii == 1, perm.index <- 1:p, perm.index <- sample(p, p))
        Gamma_c_perm <- Gamma_c[perm.index, perm.index,]

        A <- list()
        z <- xx[perm.index,]
        z[, 1:max.var.order] <- NA
        for (jj in 1:N) {
          ifelse(jj == N, block <- ((jj - 1) * (q + 1) + 1):p,
                 block <- ((jj - 1) * (q + 1) + 1):(jj * (q + 1)))
          pblock <- perm.index[block]
          nblock <- length(block)

          if(is.null(factor.var.order)) {
            bic <- common.bic(Gamma_c_perm, block, n, max.var.order)
            s <- which.min(bic[-1])
          } else {
            s <- factor.var.order
          }

          tmp <- common.yw.est(Gamma_c_perm, block, s)$A
          A <- c(A, list(tmp))
          for (ll in 1:s)
            z[block, (max.var.order + 1):n] <-
            z[block, (max.var.order + 1):n] - tmp[, nblock * (ll - 1) + 1:nblock] %*% xx[pblock, (max.var.order + 1):n - ll]
        }

        zz <-
          z[, (max.var.order + 1):n] %*% t(z[, (max.var.order + 1):n]) / (n - max.var.order)
        svz <- svd(zz, nu = q, nv = 0)
        R <- as.matrix(t(t(svz$u) * sqrt(svz$d[1:q])))
        u <- t(svz$u) %*% z / sqrt(svz$d[1:q])

        tmp.irf <- irf.array[, , , 1, drop = FALSE] * 0
        for (jj in 1:N) {
          ifelse(jj == N, block <- ((jj - 1) * (q + 1) + 1):p, block <- ((jj - 1) * (q + 1) + 1):(jj * (q + 1)))
          pblock <- perm.index[block]
          invA <- var.to.vma(A[[jj]], trunc.lags + 1)
          for (ll in 1:(trunc.lags + 2)) {
            tmp.irf[pblock, , ll,] <- invA[, , ll] %*% R[block,]
          }
        }
        B0 <- tmp.irf[1:q, , 1,]
        if(all(B0 == 0)) {
          H <- as.matrix(B0)
        } else {
          C0 <- t(chol(B0 %*% t(B0))) # cholesky identification
          H <- solve(B0) %*% C0
        }
        for (ll in 1:(trunc.lags + 2))
          irf.array[, , ll, ii] <- tmp.irf[, , ll,] %*% H
        u.array[, , ii] <- t(H) %*% u
      }

      irf.est <- apply(irf.array, c(1, 2, 3), mean)
      u.est <- apply(u.array, c(1, 2), mean)

      # out <- list(irf.array = irf.array, u.array = u.array, irf.est = irf.est, u.est = u.est)
      out <- list(irf.est = irf.est, u.est = u.est)

      return(out)
    }
  }

#' @keywords internal
#' @importFrom stats as.ts
common.restricted.predict <-
  function(xx,
           Gamma_x,
           Gamma_c,
           q,
           r = NULL,
           max.r = NULL,
           r.method = NULL,
           n.ahead = 1) {

    p <- dim(xx)[1]
    n <- dim(xx)[2]
    if(is.null(max.r))
      max.r <- max(q, min(50, round(sqrt(min(n, p)))))
    if(n.ahead >= dim(Gamma_c)[3]) {
      warning("At most ", (dim(Gamma_c)[3] - 1) / 2, "-step ahead forecast is available!")
      n.ahead <- (dim(Gamma_c)[3] - 1) / 2
    }

    if(is.null(r)) {
      if(r.method == "ic") {
        abc <- abc.factor.number(xx, covx = Gamma_x[,, 1], q.max = max.r)
        r  <- max(q, abc$q.hat[5])
        sv <- svd(Gamma_x[, , 1], nu = max.r, nv = 0)
      }
      else if(r.method == "er") {
        sv <- svd(Gamma_x[, , 1], nu = max.r, nv = 0)
        r <- which.max(sv$d[q:max.r] / sv$d[1 + q:max.r]) + q - 1
      }
    } else
      sv <- svd(Gamma_x[, , 1], nu = max.r, nv = 0)

    is <- sv$u[, 1:r, drop = FALSE] %*% t(sv$u[, 1:r, drop = FALSE]) %*% xx
    if(n.ahead >= 1) {
      fc <- matrix(0, nrow = p, ncol = n.ahead)
      proj.x <-
        t(t(sv$u[, 1:r, drop = FALSE]) / sv$d[1:r]) %*% t(sv$u[, 1:r, drop = FALSE]) %*% xx[, n]
      for (hh in 1:n.ahead)
        fc[, hh] <- t(Gamma_c[, , hh + 1]) %*% proj.x
    } else {
      fc <- NA
    }

    out <- list(is = as.ts(t(is)),
                fc = as.ts(t(fc)),
                r = r,
                n.ahead = n.ahead)
    return(out)
  }

#' @keywords internal
#' @importFrom stats as.ts
common.unrestricted.predict <- function(xx, cve, n.ahead = 1) {
  p <- dim(xx)[1]
  n <- dim(xx)[2]
  trunc.lags <- dim(cve$loadings)[3]
  if(n.ahead >= trunc.lags + 1) {
    warning("At most ", trunc.lags, "-step ahead forecast is available!")
    n.ahead <- trunc.lags
  }

  irf <- cve$loadings
  u <- cve$factors
  trunc.lags <- dim(irf)[3] - 1

  is <- xx * 0
  is[, 1:trunc.lags] <- NA
  for (ll in 1:(trunc.lags + 1))
    is[, (trunc.lags + 1):n] <-
    is[, (trunc.lags + 1):n] + as.matrix(irf[, , ll]) %*% u[, (trunc.lags + 1):n - ll + 1, drop = FALSE]

  if(n.ahead >= 1) {
    fc <- matrix(0, nrow = p, ncol = n.ahead)
    for (hh in 1:n.ahead)
      for (ll in 1:(trunc.lags + 1 - hh))
        fc[, hh] <-
          fc[, hh] + as.matrix(irf[, , ll + hh]) %*% u[, n - ll + 1, drop = FALSE]
  } else {
    fc <- NA
  }

  out <- list(is = as.ts(t(is)), fc = as.ts(t(fc)), n.ahead = n.ahead)
  return(out)
}

#' @keywords internal
common.yw.est <- function(Gcp, block, var.order) {
  nblock <- length(block)
  B <- matrix(0, nrow = nblock, ncol = nblock * var.order)
  C <-
    matrix(0, nrow = nblock * var.order, ncol = nblock * var.order)
  for (ll in 1:var.order) {
    B[, nblock * (ll - 1) + 1:nblock] <- t(Gcp[block, block, 1 + ll])
    for (lll in 1:var.order) {
        ifelse(ll >= lll,
               C[nblock * (ll - 1) + 1:nblock, nblock * (lll - 1) + 1:nblock] <-Gcp[block, block, 1 + ll - lll],
               C[nblock * (ll - 1) + 1:nblock, nblock * (lll - 1) + 1:nblock] <-t(Gcp[block, block, 1 + lll - ll]))
    }
  }
  A <- B %*% solve(C, symmetric = TRUE)
  out <- list(A = A, B = B, C = C)
  return(out)
}

#' @keywords internal
common.bic <- function(Gcp, block, len, max.var.order = 5) {
  nblock <- length(block)
  bic <- rep(0, max.var.order + 1)
  bic[1] <- log(det(Gcp[block, block, 1]))
  for (ii in 1:max.var.order) {
    cye <- common.yw.est(Gcp, block, ii)
    G0 <-
      Gcp[block, block, 1] - cye$B %*% t(cye$A) - cye$A %*% t(cye$B) + cye$A %*% cye$C %*% t(cye$A)
    bic[ii + 1] <-
      log(det(G0)) + 2 * log(len) * ii * nblock ^ 2 / len
  }
  bic
}
