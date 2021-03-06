% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{em_converged}
\alias{em_converged}
\title{Convergence test for EM-algorithm.}
\usage{
em_converged(loglik, previous_loglik, threshold = 1e-04)
}
\arguments{
\item{loglik}{Current value of the log-likelihood function}

\item{previous_loglik}{Value of the log-likelihood function at the previous}

\item{threshold}{If difference is less than threshold, then algorithm has
converged}
}
\value{
A logical statement indicating whether EM algorithm has converged
according to slope convergence test
}
\description{
Convergence test for EM-algorithm.
}
