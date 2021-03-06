#include <RcppArmadillo.h>
#include "helper.h"

// [[Rcpp::depends(RcppArmadillo)]]
using namespace arma;


//' Implementation of a Kalman filter
//' @param X Data matrix (T x n)
//' @param C Observation matrix
//' @param Q State covariance
//' @param R Observation covariance
//' @param A Transition matrix
//' @param F0 Initial state vector
//' @param P0 Initial state covariance
// [[Rcpp::export]]
Rcpp::List KalmanFilter(arma::mat X, arma::mat C, arma::mat Q, arma::mat R,
                        arma::mat A, arma::colvec F0, arma::mat P0) {

  const int T = X.n_rows;
  const int n = X.n_cols;
  const int rp = A.n_rows;

  double loglik = 0;
  mat K, Pf, Pp;
  colvec ff, fp, xe;
  // Predicted state mean and covariance
  mat PT(T+1, rp, fill::zeros);
  cube PpT(rp, rp, T+1, fill::zeros);

  // Filtered state mean and covariance
  mat FT(T, rp, fill::zeros);
  cube PfT(rp, rp, T, fill::zeros);

  mat tC = C;
  mat tR = R;
  mat S;
  uvec miss;
  uvec nmiss = find_finite(A.row(0));
  uvec a(1);

  fp = F0;
  Pp = P0;

  for (int t=0; t < T; ++t) {

    // If missing observations are present at some timepoints, exclude the
    // appropriate matrix slices from the filtering procedure.
    miss = find_finite(X.row(t));
    C = tC.submat(miss, nmiss);
    R = tR.submat(miss, miss);
    a[0] = t;

    S = (C * Pp * C.t() + R).i();

    // Prediction error
    xe = X.submat(a, miss).t() - C * fp;
    // Kalman gain
    K = Pp * C.t() * S;
    // Updated state estimate
    ff = fp + K * xe;
    // Updated state covariance estimate
    Pf = Pp - K * C * Pp;

    // Compute likelihood. Skip this part if S is not positive definite.
    if (det(S) > 0) {
      loglik += -0.5 * (double(n) * log(2.0 * datum::pi) - log(det(S)) +
        conv_to<double>::from(xe.t() * S * xe));
    }

    // Store predicted and filtered data needed for smoothing
    PT.row(t) = fp.t();
    PpT.slice(t) = Pp;
    FT.row(t) = ff.t();
    PfT.slice(t) = Pf;

    // Run a prediction
    fp = A * FT.row(t).t();
    Pp = A * PfT.slice(t) * A.t() + Q;

  }

  return Rcpp::List::create(Rcpp::Named("F") = FT,
                            Rcpp::Named("Pf") = PfT,
                            Rcpp::Named("P") = PT,
                            Rcpp::Named("Pp") = PpT,
                            Rcpp::Named("loglik") = loglik);
}


//' Runs a Kalman smoother
//' @param A transition matrix
//' @param C observation matrix
//' @param R Observation covariance
//' @param FT State estimates
//' @param PTm State predicted estimates
//' @param PfT_v Variance estimates
//' @param PpT_v Predicted variance estimates
//' @return List of smoothed estimates
// [[Rcpp::export]]
Rcpp::List KalmanSmoother(arma::mat A, arma::mat C, arma::mat R,
                          arma::mat FT, arma::mat PT,
                          Rcpp::NumericVector PfT_v, Rcpp::NumericVector PpT_v) {

  const int T = FT.n_rows;
  const int rp = A.n_rows;
  const int n = C.n_rows;

  cube PfT = array2cube(PfT_v);
  cube PpT = array2cube(PpT_v);

  cube J(rp, rp, T, fill::zeros);
  cube L(n, n, T, fill::zeros);
  cube K(rp, n, T, fill::zeros);

  cube PsTm(rp, rp, T, fill::zeros);

  // Smoothed state mean and covariance
  mat FsT(T, rp, fill::zeros);
  cube PsT(rp, rp, T, fill::zeros);
  // Initialize smoothed data with last observation of filtered data
  FsT.row(T-1) = FT.row(T-1);
  PsT.slice(T-1) = PfT.slice(T-1);

  // cube PsTm(rp,rp,T, fill::zeros);
  for (int t=0; t < T-1; ++t) {
    J.slice(t) = PfT.slice(t) * A.t() * PpT.slice(t+1).i();
  }

  // Smoothed state variable and covariance
  for (int j=2; j < T+1; ++j) {

    FsT.row(T-j) = FT.row(T-j) +
      (J.slice(T-j) * (FsT.row(T-j+1) - PT.row(T-j+1)).t()).t();

    PsT.slice(T-j) = PfT.slice(T-j) +
      J.slice(T-j) * (PsT.slice(T-j+1) - PpT.slice(T-j+1)) * J.slice(T-j).t();

  }

  // Additional variables used in EM-algorithm
  for (int i=0; i < T; ++i) {
    L.slice(i) = (C * PpT.slice(i) * C.t() + R).i();
    K.slice(i) = PpT.slice(i) * C.t() * L.slice(i);
  }

  PsTm.slice(T-1) = (eye(rp,rp) - K.slice(T-1) * C) * A * PfT.slice(T-2);

  for (int j=2; j < T-1; ++j) {
    PsTm.slice(T-j) = PfT.slice(T-j) * J.slice(T-j-1).t() + J.slice(T-j)
    * (PsTm.slice(T-j+1) - A * PfT.slice(T-j))
    * J.slice(T-j-1).t();
  }

  return Rcpp::List::create(Rcpp::Named("Fs") = FsT,
                            Rcpp::Named("Ps") = PsT,
                            Rcpp::Named("PsTm") = PsTm);
}



//' Kalman Filter and Smoother
//' @param X Data matrix (T x n)
//' @param C Observation matrix
//' @param Q State covariance
//' @param R Observation covariance
//' @param A Transition matrix
//' @param F0 Initial state vector
//' @param P0 Initial state covariance
// [[Rcpp::export]]
Rcpp::List KalmanFilterSmoother(arma::mat X, arma::mat C, arma::mat Q, arma::mat R,
                                arma::mat A, arma::colvec F0, arma::mat P0) {

  const int T = X.n_rows;
  const int n = X.n_cols;
  const int rp = A.n_rows;

  double loglik = 0;
  mat K, Pf, Pp;
  colvec ff, fp, xe;
  // Predicted state mean and covariance
  mat PT(T+1, rp, fill::zeros);
  cube PpT(rp, rp, T+1, fill::zeros);

  // Filtered state mean and covariance
  mat FT(T, rp, fill::zeros);
  cube PfT(rp, rp, T, fill::zeros);

  mat tC = C;
  mat tR = R;
  mat S;
  uvec miss;
  uvec nmiss = find_finite(A.row(0));
  uvec a(1);

  fp = F0;
  Pp = P0;

  for (int t=0; t < T; ++t) {

    // If missing observations are present at some timepoints, exclude the
    // appropriate matrix slices from the filtering procedure.
    miss = find_finite(X.row(t));
    C = tC.submat(miss, nmiss);
    R = tR.submat(miss, miss);
    a[0] = t;

    S = (C * Pp * C.t() + R).i();

    // Prediction error
    xe = X.submat(a, miss).t() - C * fp;
    // Kalman gain
    K = Pp * C.t() * S;
    // Updated state estimate
    ff = fp + K * xe;
    // Updated state covariance estimate
    Pf = Pp - K * C * Pp;

    // Compute likelihood. Skip this part if S is not positive definite.
    if (det(S) > 0) {
      loglik += -0.5 * (double(n) * log(2.0 * datum::pi) - log(det(S)) +
        conv_to<double>::from(xe.t() * S * xe));
    }

    // Store predicted and filtered data needed for smoothing
    PT.row(t) = fp.t();
    PpT.slice(t) = Pp;
    FT.row(t) = ff.t();
    PfT.slice(t) = Pf;

    // Run a prediction
    fp = A * FT.row(t).t();
    Pp = A * PfT.slice(t) * A.t() + Q;
  }

  // Kamlman Smoother
  cube J(rp, rp, T, fill::zeros);
  cube L(n, n, T, fill::zeros);
  cube KS(rp, n, T, fill::zeros);
  cube PsTm(rp, rp, T, fill::zeros);

  // Smoothed state mean and covariance
  mat FsT(T, rp, fill::zeros);
  cube PsT(rp, rp, T, fill::zeros);
  // Initialize smoothed data with last observation of filtered data
  FsT.row(T-1) = FT.row(T-1);
  PsT.slice(T-1) = PfT.slice(T-1);

  // cube PsTm(rp,rp,T, fill::zeros);
  for (int t=0; t < T-1; ++t) {
    J.slice(t) = PfT.slice(t) * A.t() * PpT.slice(t+1).i();
  }

  // Smoothed state variable and covariance
  for (int j=2; j < T+1; ++j) {

    FsT.row(T-j) = FT.row(T-j) +
      (J.slice(T-j) * (FsT.row(T-j+1) - PT.row(T-j+1)).t()).t();

    PsT.slice(T-j) = PfT.slice(T-j) +
      J.slice(T-j) * (PsT.slice(T-j+1) - PpT.slice(T-j+1)) * J.slice(T-j).t();

  }

  // Additional variables used in EM-algorithm
  for (int i=0; i < T; ++i) {
    L.slice(i) = (C * PpT.slice(i) * C.t() + R).i();
    KS.slice(i) = PpT.slice(i) * C.t() * L.slice(i);
  }

  PsTm.slice(T-1) = (eye(rp,rp) - KS.slice(T-1) * C) * A * PfT.slice(T-2);

  for (int j=2; j < T-1; ++j) {
    PsTm.slice(T-j) = PfT.slice(T-j) * J.slice(T-j-1).t() + J.slice(T-j)
    * (PsTm.slice(T-j+1) - A * PfT.slice(T-j))
    * J.slice(T-j-1).t();
  }

  return Rcpp::List::create(Rcpp::Named("Fs") = FsT,
                            Rcpp::Named("Ps") = PsT,
                            Rcpp::Named("PsTm") = PsTm,
                            Rcpp::Named("loglik") = loglik);

}
