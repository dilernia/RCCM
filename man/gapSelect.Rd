% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/gapSelect.R
\name{gapSelect}
\alias{gapSelect}
\title{Gap Statistic}
\usage{
gapSelect(x, gMax, B = 100, zs, optLambdas, ncores = 1)
}
\arguments{
\item{x}{List of \eqn{K} data matrices each of dimension \eqn{n_k} x \eqn{p}}

\item{gMax}{Maximum number of clusters or groups to consider. Must be at least 2.}

\item{B}{Number of reference data sets to generate.}

\item{zs}{\eqn{K} x \eqn{gMax} - 1 matrix with estimated cluster memberships for
each number of clusters considered.}

\item{optLambdas}{Data frame with 4 columns (lambda1, lambda2, lambda3, and \eqn{G}) and \eqn{gMax} - 1 rows. The first 3 columns
are the tuning parameter values to implement the RCCM for a given number of clusters, and
the \eqn{G} column is the number of clusters that must range from 2 to \eqn{gMax}}

\item{ncores}{Number of computing cores to use if desired to run in parallel. Optional.}
}
\value{
A list of length 3 containing:
\enumerate{
\item The optimally selected number of clusters (nclusts).
\item The \eqn{gMax} observed Gap statistics (gaps).
\item The \eqn{gMax} adjusted standard deviations of the simulated gap statistics (sigmas).
}
}
\description{
This function selects the optimal number of clusters for the
 Random Covariance Clustering Model (RCCM) based on a Gap statistic
 as proposed by Tibshirani et al. (2001).
}
\examples{
# Generate data with 2 clusters with 12 and 10 subjects respectively,
# 15 variables for each subject, 100 observations for each variable for each subject,
# the groups sharing about 50\% of network connections, and 10\% of differential connections
# within each group
set.seed(1994)
myData <- rccSim(G = 2, clustSize = 10, p = 10, n = 177, overlap = 0.20, rho = 0.10)

# Analyze simulated data with RCCM
optLambdas <- data.frame(lambda1 = 10, lambda2 = 50, lambda3 = 0.10, G = 2:3)
result2 <- rccm(x = myData$simDat, lambda1 = optLambdas$lambda1[1],
                lambda2 = optLambdas$lambda2[1], lambda3 = optLambdas$lambda3[1],
                nclusts = 2)
result3 <- rccm(x = myData$simDat, lambda1 = optLambdas$lambda1[2],
                lambda2 = optLambdas$lambda2[2], lambda3 = optLambdas$lambda3[2],
                nclusts = 3)

# Estimated cluster memberships
zHats <- cbind(apply(result2$weights, MARGIN = 2, FUN = which.max),
               apply(result3$weights, MARGIN = 2, FUN = which.max))

# Selecting number of clusters
clustRes <- gapSelect(x = myData$simDat, gMax = 3, B = 50, zs = zHats,
optLambdas = optLambdas)

}
\references{
Tibshirani, Robert, et al. "Estimating the Number of Clusters in a Data Set via the Gap
Statistic." Journal of the Royal Statistical Society: Series B (Statistical Methodology),
vol. 63, no. 2, 2001, pp. 411-423., doi:10.1111/1467-9868.00293.
}
\author{
Andrew DiLernia
}
