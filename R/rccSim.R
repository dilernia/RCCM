#' Simulation of Data for RCCM
#'
#' This function simulates data based on the Random Covariance Clustering Model (RCCM).
#' Data is generated in a hierarchical manner, beginning with group-level networks
#' and precision matrices and then subject-level networks and matrices.
#'
#' For simulating data for hub type graphs, \eqn{G} cluster-level networks are first generated,
#' each with floor(\eqn{\sqrt p})
#' hubs and thus \eqn{E = p -} floor(\eqn{\sqrt p}) edges.  For generating random graphs,
#' \eqn{G} cluster-level networks are generating such that nodes are connected
#' with a probability specified by \eqn{eprob}, yielding approximately \eqn{E=} (\eqn{p} choose 2) \eqn{x eprob} edges.
#' Cluster-level networks are forced
#' to share \eqn{s =} floor(\eqn{overlap} x \eqn{E}) edges.
#' Note that \eqn{overlap} represents the approximate proportion
#' of edges that are common across the cluster-level networks.
#'
#' Then, for the \eqn{K} subject-level matrices, we first randomly
#' assign them to the \eqn{G} clusters, and then subject-level
#' networks are generated by randomly selecting
#' floor(\eqn{rho} x \eqn{E}) node pairs to add or remove an edge
#' from their corresponding cluster-level network.
#' Non-zero entries for all precision matrices are generated from
#' a uniform distribution with support on the interval
#' [-1, -0.50] U [0.50, 1],
#' and are adjusted until positive definite matrices are obtained.
#' @param G Positive integer. Number of groups or clusters.
#' @param clustSize Positive integer or vector of positive integers. Number of subjects in each cluster.
#' @param p Positive integer. Number of variables for each subject.
#' @param n Positive integer. Number of observations for each subject on each variable.
#' @param overlap Positive number between 0 and 1. Approximate proportion of overlapping edges across cluster-level networks.
#' @param rho Positive number between 0 and 1. Approximate proportion of differential edges for subjects compared to their corresponding cluster-level network.
#' @param esd Standard deviation of mean 0 noise added to generated subject-level matrices for variation from the corresponding group-level matrix.
#' @param type Graph type. Options are "hub" or "random".
#' @param eprob Probability of two nodes having an edge between them. Only applicable if type = "random".
#' @return A list of length 5 containing:
#' \enumerate{
#' \item list of \eqn{K} multivariate-Gaussian data sets each of dimension \eqn{n_k} x \eqn{p} (simDat).
#' \item \eqn{p} x \eqn{p} x \eqn{G} array of \eqn{G} number of cluster-level networks (g0s).
#' \item \eqn{p} x \eqn{p} x \eqn{G} array of \eqn{G} number of cluster-level precision matrices (Omega0s).
#' \item \eqn{p} x \eqn{p} x \eqn{K} array of \eqn{K} number of subject-level precision matrices (Omegaks).
#' \item vector of length \eqn{K} containing cluster memberships for each subject (zgks).
#' }
#'
#' @author
#' Andrew DiLernia
#'
#' @examples
#' # Generate data with 2 clusters with 12 and 10 subjects respectively,
#' # 15 variables for each subject, 100 observations for each variable for each subject,
#' # the groups sharing about 50% of network connections, and 10% of differential connections
#' # within each group
#' myData <- rccSim(G = 2, clustSize = c(12, 10), p = 15, n = 100, overlap = 0.50, rho = 0.10)
#'
#' # View list of simulated data
#' View(myData)
#'
#' @export
rccSim <- function(G = 2, clustSize = c(67, 37), p = 10,
                   n = 177, overlap = 0.50, rho = 0.10, esd = 0.05, type = "hub", eprob = 0.50) {

  # Calculating total number of subjects
  K <- ifelse(length(clustSize) == 1, G * clustSize, sum(clustSize))

  # Cluster Networks --------------------------------------------------------
  g0s <- array(0, c(p, p, G))
  gks <- array(0, c(p, p, K))
  Omega0s <- array(0, c(p, p, G))
  Omegaks <- array(0, c(p, p, K))
  if(length(clustSize) != 1 & length(clustSize) != G) {
    stop("clustSize must be of length 1 or of length equal to the number of clusters")
  } else {
  if (length(clustSize) > 1) {
    zgks <- c()
    for (g in 1:length(clustSize)) {
      zgks <- c(zgks, rep(g, clustSize[g]))
    }
  } else {
    zgks <- sort(rep(1:G, clustSize))
  }
  }
  simDat <- list()

  # Manually generating cluster-level graphs and precision matrices

  # Number of hubs
  J <- floor(sqrt(p))

  # Function for dividing entries by corresponding row sums to make positive definite
  symmPosDef <- function(m) {
    m <- m + t(m)
    smallE <- min(eigen(m)$values)
    if (smallE <= 0) {
      m <- m + diag(rep(abs(smallE) + 0.10 + 0.10, times = nrow(m)))
    }
    return(m)
  }

  # Determining edges to be shared across groups
  numE <- p - J
  q <- choose(p, 2)
  numShare <- ifelse(type == "hub", floor(numE * overlap), floor(q * overlap))
  eShare <- matrix(which(lower.tri(matrix(1, p, p), diag = F),
                         arr.ind = TRUE)[sample(1:q, size = numShare), ], ncol = 2)
  shared <- sample(c(1, 0), size = nrow(eShare), replace = TRUE, prob = c(eprob, 1 - eprob))

  # Different graphs if balanced clusters or not
  balanced <- ifelse(length(clustSize) > 1, "_unbal", "")

  # Generating group-level graphs and precision matrices
  while (min(apply(Omega0s, MARGIN = 3, FUN = function(x) {
    min(eigen(x)$values)})) <= 0) {
    for (g in 1:G) {
        g0s[, , g] <- matrix(0, nrow = p, ncol = p)

        if(type == "hub") {
          hubs <- split(sample.int(p, size = p, replace = FALSE), rep(1:J, ceiling(p / J))[1:p])

          for (h in 1:J) {
            for (v in hubs[[h]]) {
              g0s[, , g][hubs[[h]][1], v] <- 1
            }
          }
        } else if(type == "random") {
          offInds <- lower.tri(g0s[, , g], diag = FALSE)
          g0s[, , g][offInds] <- sample(c(1, 0), size = sum(offInds),
                                        replace = TRUE, prob = c(eprob, 1 - eprob))
        }

        # Adding in numShare shared edges
        for (e in 1:nrow(eShare)) {
          g0s[, , g][eShare[e, 1], eShare[e, 2]] <- shared[e]
        }

        # Saving graphs to keep constant across simulations
        g0s[, , g] <- (g0s[, , g] + t(g0s[, , g]) > 0.001) + 0

      # Making graph triangular for precision matrix generation and storing row edge count
      g0s[, , g] <- (g0s[, , g] + t(g0s[, , g]) > 0.001) + 0
      rwSum <- rowSums(g0s[, , g])
      g0s[, , g][upper.tri(g0s[, , g], diag = T)] <- 0

      Omega0s[, , g] <- g0s[, , g] * matrix(runif(n = p * p, min = 0.50, max = 1) * sample(c(1, -1),
                                                                                           size = p * p, replace = T), nrow = p, ncol = p)
      if (g > 1) {
        for (e in 1:nrow(eShare)) {
          Omega0s[, , g][eShare[e, 1], eShare[e, 2]] <- Omega0s[, , g - 1][eShare[e, 1], eShare[e, 2]]
        }
      }

      # Making matrix symmetric and positive definite
      Omega0s[, , g] <- symmPosDef(Omega0s[, , g])

      # Making graph full again, not just lower triangular
      g0s[, , g] <- g0s[, , g] + t(g0s[, , g])
    }
  }

  # Generating subject-level matrices
  while (min(apply(Omegaks, MARGIN = 3, FUN = function(x) {
    min(eigen(x)$values)})) <= 0) {
    for (k in 1:K) {
      # Creating subject-level graph to be exactly same as group-level graph for now
      gks[, , k] <- matrix(0, nrow = p, ncol = p)
      gks[, , k][lower.tri(gks[, , k], diag = FALSE)] <- g0s[, , zgks[k]][lower.tri(g0s[, , zgks[k]],
                                                                                    diag = FALSE)]

      # Forcing subject-level matrix to have similar value as group-level matrix
      Omegaks[, , k] <- gks[, , k] * (Omega0s[, , zgks[k]] + matrix(rnorm(n = p * p, sd = esd),
                                                                    nrow = p, ncol = p))


      # Changing edge presence for floor(rho * E) pairs of vertices from group-level graph
      if (floor(rho * sum(gks[, , k])) > 0) {
        # Determining which %rho*100 of node pairs to change edge presence for
        swaps <- matrix(which(lower.tri(matrix(1, p, p), diag = F),
                              arr.ind = TRUE)[sample(1:(p * (p - 1) / 2),
                              size = floor(rho * sum(gks[, , k]))), ], ncol = 2)

        for (s in 1:nrow(swaps)) {
          gks[, , k][swaps[s, 1], swaps[s, 2]] <- abs(gks[, , k][swaps[s, 1], swaps[s, 2]] - 1)
          Omegaks[, , k][swaps[s, 1], swaps[s, 2]] <- ifelse(gks[, , k][swaps[s, 1], swaps[s, 2]] == 1,
                                                             runif(0.50, 1, n = 1) * sample(c(-1, 1), size = 1), 0)
        }
      }

      # Making graph symmetric
      gks[, , k] <- gks[, , k] + t(gks[, , k])

      # Making matrix symmetric and positive definite
      Omegaks[, , k] <- symmPosDef(Omegaks[, , k])
    }
  }
  for (k in 1:K) {
    # Generating subject data
    simDat[[k]] <- mvtnorm::rmvnorm(n = n, sigma = solve(Omegaks[, , k]))
  }

  # Centering generated data
  simDat <- lapply(simDat, FUN = scale, scale = FALSE)

  results <- list(simDat = simDat, g0s = g0s, Omega0s = Omega0s,
                  Omegaks = Omegaks, zgks = zgks)

  return(results)
}
