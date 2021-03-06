# Generated by using Rcpp::compileAttributes() -> do not edit by hand
# Generator token: 10BE3573-1514-4C36-9D1C-5A225CD40393

Estep <- function(X, C, Q, R, A, F0, P0) {
    .Call(`_DFM_Estep`, X, C, Q, R, A, F0, P0)
}

#' Implementation of a Kalman filter
#' @param X Data matrix (T x n)
#' @param C Observation matrix
#' @param Q State covariance
#' @param R Observation covariance
#' @param A Transition matrix
#' @param F0 Initial state vector
#' @param P0 Initial state covariance
KalmanFilter <- function(X, C, Q, R, A, F0, P0) {
    .Call(`_DFM_KalmanFilter`, X, C, Q, R, A, F0, P0)
}

#' Runs a Kalman smoother
#' @param A transition matrix
#' @param C observation matrix
#' @param R Observation covariance
#' @param FT State estimates
#' @param PTm State predicted estimates
#' @param PfT_v Variance estimates
#' @param PpT_v Predicted variance estimates
#' @return List of smoothed estimates
KalmanSmoother <- function(A, C, R, FT, PT, PfT_v, PpT_v) {
    .Call(`_DFM_KalmanSmoother`, A, C, R, FT, PT, PfT_v, PpT_v)
}

#' Kalman Filter and Smoother
#' @param X Data matrix (T x n)
#' @param C Observation matrix
#' @param Q State covariance
#' @param R Observation covariance
#' @param A Transition matrix
#' @param F0 Initial state vector
#' @param P0 Initial state covariance
KalmanFilterSmoother <- function(X, C, Q, R, A, F0, P0) {
    .Call(`_DFM_KalmanFilterSmoother`, X, C, Q, R, A, F0, P0)
}

ainv <- function(x) {
    .Call(`_DFM_ainv`, x)
}

apinv <- function(x) {
    .Call(`_DFM_apinv`, x)
}

