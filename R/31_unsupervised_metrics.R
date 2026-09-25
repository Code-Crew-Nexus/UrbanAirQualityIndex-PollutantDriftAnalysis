# ==============================================================================
# R/31_unsupervised_metrics.R
# Reusable helpers for Phase 5A: PCA, K-Means, Silhouette, ARI & Diagnostics
# ==============================================================================

library(cluster)

#' Calculate Adjusted Rand Index (Hubert & Arabie, 1985) deterministically in base R
#' @param c1 Integer or character vector of cluster assignments
#' @param c2 Integer or character vector of cluster assignments
#' @return Numeric scalar ARI in [-1, 1]
calc_ari <- function(c1, c2) {
  if (length(c1) != length(c2)) {
    stop("c1 and c2 must have identical lengths")
  }
  tab <- table(c1, c2)
  n <- sum(tab)
  if (n <= 1) return(1.0)
  
  # Helper for n choose 2
  choose2 <- function(x) {
    x * (x - 1) / 2
  }
  
  sum_comb_tab <- sum(choose2(tab))
  sum_comb_rows <- sum(choose2(rowSums(tab)))
  sum_comb_cols <- sum(choose2(colSums(tab)))
  comb_n <- choose2(n)
  
  expected_index <- (sum_comb_rows * sum_comb_cols) / comb_n
  max_index <- 0.5 * (sum_comb_rows + sum_comb_cols)
  denominator <- max_index - expected_index
  
  if (abs(denominator) < 1e-12) {
    return(ifelse(sum_comb_tab == max_index, 1.0, 0.0))
  }
  
  ari <- (sum_comb_tab - expected_index) / denominator
  return(as.numeric(ari))
}

#' Calculate Average Silhouette Width in Euclidean space
#' @param data Matrix or data.frame of coordinates (e.g. retained PCA scores)
#' @param clusters Integer or factor vector of cluster assignments
#' @return Numeric average silhouette width
calc_avg_silhouette <- function(data, clusters) {
  if (length(unique(clusters)) < 2 || length(unique(clusters)) >= nrow(data)) {
    return(NA_real_)
  }
  d <- dist(data, method = "euclidean")
  sil <- silhouette(as.integer(as.factor(clusters)), d)
  return(mean(sil[, "sil_width"]))
}

#' Calculate Euclidean distance from points to a set of centroids
#' @param points Matrix or data.frame (N x D)
#' @param centroids Matrix or data.frame (K x D)
#' @return Matrix of distances (N x K)
calc_distance_to_centroids <- function(points, centroids) {
  p_mat <- as.matrix(points)
  c_mat <- as.matrix(centroids)
  k <- nrow(c_mat)
  n <- nrow(p_mat)
  dists <- matrix(0, nrow = n, ncol = k)
  for (j in 1:k) {
    diffs <- sweep(p_mat, 2, c_mat[j, ], "-")
    dists[, j] <- sqrt(rowSums(diffs^2))
  }
  return(dists)
}

#' Assign points to nearest centroid and return assigned cluster and distance
#' @param points Matrix or data.frame of points
#' @param centroids Matrix of centroids with rownames or 1:K indexing
#' @return data.frame with columns assigned_cluster, distance_to_assigned_centroid
assign_to_nearest_centroid <- function(points, centroids) {
  dists <- calc_distance_to_centroids(points, centroids)
  nearest_idx <- apply(dists, 1, which.min)
  nearest_dist <- dists[cbind(1:nrow(dists), nearest_idx)]
  
  cluster_names <- if (!is.null(rownames(centroids))) {
    rownames(centroids)[nearest_idx]
  } else {
    as.character(nearest_idx)
  }
  
  data.frame(
    assigned_cluster = cluster_names,
    distance_to_assigned_centroid = nearest_dist,
    stringsAsFactors = FALSE
  )
}
