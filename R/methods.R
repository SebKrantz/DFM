#' @name summary.dfm
#' @aliases print.dfm
#' @aliases summary.dfm
#' @aliases print.dfm_summary
#'
#' @title DFM Summary Methods
#'
#' @description Summary and print methods for class 'dfm'. \code{print.dfm} just prints basic model information and the factor transition matrix [A],
#' \code{summary.dfm} returns all system matrices and additional residual and goodness of fit statistics - with a print method allowing full or compact printout.
#'
#' @param x,object an object class 'dfm'.
#' @param digits integer. The number of digits to print out.
#' @importFrom collapse qsu
#' @export
print.dfm <- function(x,
                      digits = 4L, ...) {

  X <- x$X_imp
  A <- x$A
  r <- dim(A)[1L]
  p <- dim(A)[2L]/r
  cat("Dynamic Factor Model: n = ", dim(X)[2L], ", T = ", dim(X)[1L], ", r = ", r, ", p = ", p, ", %NA = ",
      if(x$anyNA) round(sum(attr(X, "missing"))/prod(dim(X))*100, digits) else 0,"\n", sep = "")
  fnam <- paste0("f", seq_len(r))
  cat("\nFactor Transition Matrix [A]\n")
  print(round(A, digits))
}

#' @rdname summary.dfm
#' @param method character. The factor estimates to use: one of \code{"qml"}, \code{"twostep"} or \code{"pca"}.
#' @return Summary information following a dynamic factor model estimation.
#' @importFrom stats cov
#' @importFrom collapse pwcov
#' @export
summary.dfm <- function(object,
                        method = if(is.null(object$qml)) "twostep" else "qml", ...) {

  X <- object$X_imp
  F <- object[[method]]
  A <- object$A
  r <- dim(A)[1L]
  p <- dim(A)[2L] / r
  C <- object$C
  res <- X - tcrossprod(F, C)
  anymissing <- object$anyNA
  if(anymissing) res[attr(X, "missing")] <- NA
  rescov <- pwcov(res, use = if(anymissing) "pairwise.complete.obs" else "everything", P = TRUE)
  ACF <- AC1(res, anymissing)
  R2 <- 1 - diag(rescov[,, 1L])
  summ <- list(info = c(n = dim(X)[2L], T = dim(X)[1L], r = r, p = p,
                        `%NA` = if(anymissing) sum(attr(X, "missing")) / prod(dim(X)) * 100 else 0),
               call = object$call,
               F_stats = msum(F),
               A = A,
               F_cov = pwcov(F, P = TRUE),
               Q = object$Q,
               C = C,
               R_diag = diag(object$R),
               res_cov = rescov,
               res_ACF = ACF,
               R2 = R2,
               R2_stats = msum(R2))
  class(summ) <- "dfm_summary"
  return(summ)
}

#' @rdname summary.dfm
#' @param compact integer. Display a more compact printout: \code{0} prints everything, \code{1} omits the observation matrix [C] and covariance matrix [R], and \code{2} omits all disaggregated information - yielding a summary of only the factor estimates.
#' @export
print.dfm_summary <- function(x,
                              digits = 4L,
                              compact = sum(x$info["n"] > 15, x$info["n"] > 40), ...) {

  inf <- as.integer(x$info[1:4])
  cat("Dynamic Factor Model: n = ", inf[1L], ", T = ", inf[2L], ", r = ", inf[3L], ", p = ", inf[4L],
      ", %NA = ", round(x$info[5L], digits), "\n", sep = "")
  cat("\nCall: ", deparse(x$call))
  # cat("\nModel: ", ))
  cat("\n\nSummary Statistics of Factors [F]\n")
  print(x$F_stats, digits)
  cat("\nFactor Transition Matrix [A]\n")
  print(x$A, digits = digits)
  cat("\nFactor Covariance Matrix [cov(F)]\n")
  print(x$F_cov, digits)
  cat("\nFactor Transition Error Covariance Matrix [Q]\n")
  print(round(x$Q, digits))
  if(compact == 0L) {
  cat("\nObservation Matrix [C]\n")
  print(round(x$C, digits))
  }
  if(compact < 2L) {
  cat("\nObservation Error Covariance Matrix [diag(R) - Restricted]\n")
  # cat("\n Estimated Diagonal (DFM Assumes R is Diagonal)\n")
  print(round(x$R_diag, digits))
  }
  if(compact == 0L) {
  cat("\nObservation Residual Covariance Matrix [cov(resid(DFM))]\n")
  print(x$res_cov, digits)
  }
  if(compact < 2L) {
  cat("\nResidual AR(1) Serial Correlation\n")
  print(x$res_ACF, digits) # TODO: Add P-Value
  cat("\nGoodness of Fit: R-Squared\n")
  print(x$R2, digits)
  }
  cat("\nSummary of Individual R-Squared's\n")
  print(x$R2_stats, digits)
}


#' Plot DFM
#' @param x an object class 'dfm'.
#' @param method character. The factor estimates to use: one of \code{"qml"}, \code{"twostep"} or \code{"pca"}.
#' @param type character. The type of plot: \code{"joint"}, \code{"individual"} or \code{"residual"}.
#' @importFrom graphics boxplot
#' @export
plot.dfm <- function(x,
                     method = if(is.null(x$qml)) "twostep" else "qml",
                     type = c("joint", "individual", "residual"), ...) {
  F <- switch(method[1L],
              all = cbind(x$pca, setCN(x$twostep, paste("2S", colnames(x$twostep))),
                          if(length(x$qml)) setCN(x$qml, paste("QML", colnames(x$qml))) else NULL),
              pca = x$pca, twostep = x$twostep, qml = x$qml, stop("Unknown method:", method[1L]))
  nf <- dim(F)[2L]
  switch(type[1L],
    joint = {
      Xr <- range(x$X_imp)
      Fr <- range(F)
      ts.plot(x$X_imp, col = "grey85", ylim = c(min(Xr[1L], Fr[1L]), max(Xr[2L], Fr[2L])),
              ylab = "Value", main = "Standardized Series and Factor Estimates")
      cols <- rainbow(nf)
      for (i in seq_len(nf)) lines(F[, i], col = cols[i])
      legend("topleft", colnames(F), col = cols, lty = 1, bty = "n")
    },
    individual = { # TODO: Reduce plot margins
      if(method[1L] == "all") {
        qml <- !is.null(x$qml)
        nf <- nf / (2L + qml)
        oldpar <- par(mfrow = c(nf, 1L))
        on.exit(par(oldpar))
        for (i in seq_len(nf)) {
          plot(F[, i], type = 'l', main = paste("Factor", i), col = "red", ylab = "Value",
               xlab = if(i == nf) "Time" else "")
          lines(F[, i + nf], type = 'l', col = "orange")
          if(qml) lines(F[, i + 2L * nf], type = 'l', col = "blue")
          if(i == 1L) legend("topleft", c("PCA", "2S", if(qml) "QML"),
                             col = c("red", "orange", "blue"), lty = 1, bty = "n")
        }
      } else {
        oldpar <- par(mfrow = c(nf, 1L))
        on.exit(par(oldpar))
        cnF <- colnames(F)
        for (i in seq_len(nf)) plot(F[, i], type = 'l', main = cnF[i], ylab = "Value",
                                    xlab = if(i == nf) "Time" else "")
      }
    },
    residual = {
      if(method[1L] == "all") stop("Need to choose a specific method for residual plots")
      boxplot(x$X_imp - tcrossprod(F, x$C), main = "Residuals by input variable")
    },
    stop("Unknown plot type: ", type[1L])
  )
}

#' @name residuals.dfm
#' @aliases residuals.dfm
#' @aliases resid.dfm
#' @aliases fitted.dfm
#'
#' @title DFM Residuals and Fitted Values
#'
#' @param object an object of class 'dfm'.
#' @param method character. The factor estimates to use: one of \code{"qml"}, \code{"twostep"} or \code{"pca"}.
#' @param orig.format logical. \code{TRUE} returns residuals/fitted values in a data format similar to \code{X}.
#' @param standardized logical. \code{FALSE} will put residuals/fitted values on the original data scale.
#' @importFrom collapse TRA.matrix mctl setAttrib pad
#' @export
residuals.dfm <- function(object,
                          method = if(is.null(object$qml)) "twostep" else "qml",
                          orig.format = FALSE,
                          standardized = FALSE, ...) {
  X <- object$X_imp
  X_pred <- tcrossprod(object[[method]], object$C)
  if(!standardized) {
    stats <- attr(X, "stats")
    X_pred <- unscale(X_pred, stats)
    res <- unscale(X, stats) - X_pred
  } else res <- X - X_pred
  if(object$anyNA) res[attr(X, "missing")] <- NA
  if(orig.format) {
    if(length(object$na.rm)) res <- pad(res, object$na.rm, method = "vpos")
    if(attr(X, "is.list")) res <- mctl(res)
    return(setAttrib(res, attr(X, "attributes")))
  }
  return(qM(res))
}

resid.dfm <- residuals.dfm

#' @rdname residuals.dfm
#' @export
fitted.dfm <- function(object,
                       method = if(is.null(object$qml)) "twostep" else "qml",
                       orig.format = FALSE,
                       standardized = FALSE, ...) {
  X <- object$X_imp
  res <- tcrossprod(object[[method]], object$C)
  if(!standardized) res <- unscale(res, attr(X, "stats"))
  if(object$anyNA) res[attr(X, "missing")] <- NA
  if(orig.format) {
    if(length(object$na.rm)) res <- pad(res, object$na.rm, method = "vpos")
    if(attr(X, "is.list")) res <- mctl(res)
    return(setAttrib(res, attr(X, "attributes")))
  }
  return(qM(res))
}

#' @name predict.dfm
#' @aliases forecast.dfm
#' @aliases print.dfm_forecast
#' @aliases plot.dfm_forecast
#'
#' @title DFM Forecasts
#'
#' @description This function produces h-step ahead forecasts of both the factors and the data,
#' with an option to also forecast autocorrelated residuals with a univariate method and produce a combined forecast.
#'
#' @param object an object of class 'dfm'.
#' @param h integer. The forecast horizon.
#' @param method character. The factor estimates to use: one of \code{"qml"}, \code{"twostep"} or \code{"pca"}.
#' @param resFUN an (optional) function to compute a univariate forecast of the residuals.
#' The function needs to have a second argument providing the forecast horizon (\code{h}) and return a vector or forecasts. See Examples.
#' @param resAC numeric. Threshold for residual autocorrelation to apply \code{resFUN}: only residual series where AC1 > resAC will be forecasted.
#'
#' @examples
#' dfm <- DFM(diff(Seatbelts[, 1:7], lag = 12), 3, 3)
#' predict(dfm)
#' fcfun <- function(x, h) predict(ar(x), n.ahead = h)$pred
#' predict(dfm, resFUN = fcfun)
#'
#' @export
# TODO: Prediction in original format??
predict.dfm <- function(object,
                        h = 10L,
                        method = if(is.null(object$qml)) "twostep" else "qml",
                        standardized = TRUE,
                        resFUN = NULL,
                        resAC = 0.1, ...) {

  F <- object[[method]]
  nf <- dim(F)[2L]
  C <- object$C
  ny <- dim(C)[1L]
  A <- object$A
  r <- dim(A)[1L]
  p <- dim(A)[2L] / r
  X <- object$X_imp

  F_fc <- matrix(NA_real_, nrow = h, ncol = nf)
  X_fc <- matrix(NA_real_, nrow = h, ncol = ny)
  F_last <- ftail(F, p)   # dimnames(F_last) <- list(c("L2", "L1"), c("f1", "f2"))
  spi <- p:1

  for (i in seq_len(h)) {
    F_reg <- ftail(F_last, p)
    F_fc[i, ] <- A %*% `dim<-`(t(F_reg)[, spi, drop = FALSE], NULL)
    X_fc[i, ] <- C %*% F_fc[i, ]
    F_last <- rbind(F_last, F_fc[i, ])
  }
  # TODO: What about missing values??
  if(!is.null(resFUN)) {
    if(!is.function(resFUN)) stop("resFUN needs to be a forecasting function with second argument h that produces a numeric h-step ahead forecast of a univariate time series")
    ofl <- !attr(X, "is.list") && length(attr(X, "attributes")[["class"]])
    resid <- residuals(object, method, orig.format = ofl, standardized = TRUE)
    if(ofl && length(object$na.rm)) resid <- resid[-object$na.rm, , drop = FALSE] # drop = FALSE?
    ACF <- AC1(resid, object$anyNA)
    fcr <- which(abs(ACF) >= abs(resAC)) # TODO: Check length of forecast??
    for (i in fcr) X_fc[, i] <- X_fc[, i] + as.numeric(resFUN(resid[, i], h, ...))
  } else fcr <- NULL
  # TODO: Unstandardize factors with the average mean and SD??
  if(!standardized) {
    stats <- attr(X, "stats")
    X_fc <- unscale(X_fc, stats)
    X <- unscale(X, stats)
  }

  dimnames(X_fc) <- list(NULL, dimnames(X)[[2L]])
  dimnames(F_fc) <- dimnames(F)

  if(object$anyNA) X[attr(X, "missing")] <- NA

  # model = object, # Better only save essential objects ??
  res <- list(X_fcst = X_fc,
              F_fcst = F_fc,
              X = X,
              F = F,
              method = method,
              h = h,
              resid.fc = !is.null(resFUN), # TODO: Rename list elements??
              resid.fc.ind = fcr,
              call = match.call())
  class(res) <- "dfm_forecast"
  return(res)
}

forecast.dfm <- predict.dfm

#' @rdname predict.dfm
#' @param digits integer. The number of digits to print out.
#' @export
print.dfm_forecast <- function(x,
                               digits = 4L, ...) {
  h <- x$h
  cat(h, "Step Ahead Forecast from Dynamic Factor Model\n\n")
  cat("Factor Forecasts\n")
  F_fcst <- x$F_fcst
  dimnames(F_fcst)[[1L]] <- seq_len(h)
  print(round(F_fcst, digits))
  cat("\nSeries Forecasts\n")
  X_fcst <- x$X_fcst
  dimnames(X_fcst)[[1L]] <- seq_len(h)
  print(round(X_fcst, digits))
}

#' @rdname predict.dfm
#' @param main,xlab,ylab character. Graphical parameters passed to \code{\link{ts.plot}}.
#' @param factors integers indicating which factors to display. Setting this to \code{NA}, \code{NULL} or \code{0} will omit factor plots.
#' @param factor.col,factor.lwd graphical parameters affecting the colour and line width of factor estimates plots. See \code{\link{par}}.
#' @param fcst.lty integer or character giving the line type of the forecasts of factors and data. See \code{\link{par}}.
#' @param data.col character vector of length 2 indicating the colours of historical data and forecasts of that data. Setting this to \code{NA}, \code{NULL} or \code{""} will not plot data and data forecasts.
#' @param legend logical. \code{TRUE} draws a legend in the top-left of the chart.
#' @param legend.items character names of factors for the legend.
#' @param grid logical. \code{TRUE} draws a grid on the background of the plot.
#' @param vline logical. \code{TRUE} draws a vertical line deliminaing historical data and forecasts.
#' @param vline.lty,vline.col graphical parameters affecting the appearance of the vertical line. See \code{\link{par}}.
#' @param \dots further arguments passed to \code{\link{ts.plot}}. Sensible choices are \code{xlim} and \code{ylim} to restrict the plot range.
#' @export
# TODO: multiple plot types...# , type = c("joint", "individual")
# also arguments show = c("both", "factors", "data"), and
# Also put plot on original timescale if ts object
plot.dfm_forecast <- function(x,
                              main = paste(x$h, "Period Ahead DFM Forecast"),
                              xlab = "Time", ylab = "Standardized Data",
                              factors = 1:ncol(x$F), factor.col = rainbow(length(factors)), factor.lwd = 1.5,
                              fcst.lty = "dashed",
                              data.col = c("grey85", "grey65"),
                              legend = TRUE, legend.items = paste0("f", factors),
                              grid = FALSE, vline = TRUE, vline.lty = "dotted", vline.col = "black", ...) {

  dcl <- is.character(data.col[1L]) && nzchar(data.col[1L])
  ffl <- length(factors) && !is.na(factors[1L]) && factors[1L] > 0L
  nyliml <- !(...length() && any(...names() == "ylim"))
  if(!ffl) factors <- 1L
  F <- x$F[, factors, drop = FALSE]
  r <- ncol(F)
  T <- nrow(F)
  if(ffl) {
    if(nyliml) Fr <- range(F)
    F_fcst <- x$F_fcst[, factors, drop = FALSE]
    F <- rbind(F, matrix(NA_real_, x$h, r))
  } else Fr <- NULL
  if(dcl) {
    X <- x$X
    n <- ncol(X)
    if(nyliml) {
      Xr <- range(X, na.rm = TRUE)
      Pr <- range(if(ffl) c(F_fcst, x$X_fcst) else x$X_fcst)
    }
    X_fcst <- rbind(matrix(NA_real_, T-1L, n), X[T, , drop = FALSE], x$X_fcst)
    X <- rbind(X, matrix(NA_real_, x$h, n))
  } else {
    data.col <- Xr <- NULL
    X <- F[, 1L]
    if(nyliml) Pr <- range(F_fcst)
  }
  if(ffl) F_fcst <- rbind(matrix(NA_real_, T-1L, r), F[T, , drop = FALSE], F_fcst)
  if(nyliml) {
    ts.plot(X, col = data.col[1L],
            ylim = c(min(Xr[1L], Fr[1L], Pr[1L]), max(Xr[2L], Fr[2L], Pr[1L])),
            main = main, xlab = xlab, ylab = ylab, ...)
  } else ts.plot(X, col = data.col[1L], main = main, xlab = xlab, ylab = ylab, ...)
  if(grid) grid()
  if(dcl) for (i in seq_len(n)) lines(X_fcst[, i], col = data.col[2L], lty = fcst.lty)
  if(ffl) for (i in seq_len(r)) {
    lines(F[, i], col = factor.col[i], lwd = factor.lwd)
    lines(F_fcst[, i], col = factor.col[i], lwd = factor.lwd, lty = fcst.lty)
  }
  if(ffl && legend) legend("topleft", legend.items, col = factor.col,
                           lwd = factor.lwd, lty = 1L, bty = "n")
  if(vline) abline(v = T, col = vline.col, lwd = 1L, lty = vline.lty)
}

# interpolate.dfm <- function(x, method = "qml", interpolate = TRUE) {
#   W <- is.na(data)
#   stats <- qsu(data)
#   STDdata <- fscale(data)
#   if(nrow(x$C) != ncol(data)) stop("dimension mismatch")
#   Fcst <- tcrossprod(x[[method]], x$C)
#   # TODO: Make this work for data.table...
#   STDdata[W] <- Fcst[W]
#   STDdata <- ((STDdata %r*% stats[, "SD"]) %r+% stats[, "Mean"])
#   data[W] <- STDdata[W]
#   data
# }
#
# nowcast.dfm <- function(x, method = "qml", ...) {
# }
#
# backcast.dfm <- function(x, method = "qml", ...) {
# }
