#' Estimate SD robustly using the half IQR
#' 
#' Estimates standard deviation robustly using the half IQR (and power trans.).
#'  Used to measure DVARS in Afyouni and Nichols, 2018. 
#'
#' @param x Numeric vector of data to estimate standard deviation for. 
#' @param d The scalar power transformation parameter. \eqn{w = x^{1/d}} is
#'  computed to obtain \eqn{w \sim N(\mu_w, \sigma_w^2)}.
#' 
#' @importFrom stats quantile median
#' 
#' @return Scalar for the robust estimate of standard deviation.
#' 
#' @keywords internal
#' 
sd_hIQR <- function(x, d=1){
  w <- x^(1/d) # Power trans.: w~N(mu_w, sigma_w^2)
  sd <- (quantile(w, .5) - quantile(w, .25)) / (1.349/2) # hIQR
  out <- (d * median(w)^(d - 1)) * sd # Delta method
  # In the paper, the above formula incorrectly has d^2 instead of d.
  # The code on github correctly uses d.
  return(as.numeric(out))
}

#' Mode of data vector
#' 
#' Get mode of a data vector. But use the median instead of the mode if all 
#'  data values are unique.
#' 
#' @param x The data vector
#' 
#' @return The mode
#' 
#' @keywords internal
#' 
Mode <- function(x) {
  q <- unique(x)
  # Use median instead of the mode if all data values are unique.
  if (length(q) == length(x)) { return(median(x)) }
  q[which.max(tabulate(match(x, q)))]
}

#' Convert data values to percent signal.
#' 
#' Convert data values to percent signal.
#' 
#' @param X a \eqn{T \times N} numeric matrix. The columns will be normalized to
#'  percent signal.
#' @param center A function that computes the center of a numeric vector.
#'  Default: \code{median}. Other common options include \code{mean} and 
#'  \code{mode}.
#' @param by Should the center be measured individualy for each \code{"column"}
#'  (default), or should the center be the same across \code{"all"} columns?
#' 
#' @return \code{X} with its columns normalized to percent signal. (A value of
#'  85 will represent a -15% signal change.)
#' 
#' @export
pct_sig <- function(X, center=median, by=c("column", "all")){
  stopifnot(is.numeric(X))
  stopifnot(length(dim(X))==2)
  stopifnot(is.function(center))
  by <- match.arg(by, c("column", "all"))

  T_ <- nrow(X); N_ <- ncol(X)
  X <- t(X)

  if (by=="column") {
    m <- apply(X, 1, center)
  } else {
    m <- center(as.numeric(X))
  }

  t(X / m * 100)
}

#' DVARS
#' 
#' Computes the DSE decomposition and DVARS-related statistics.
#' 
#' Citation: Insight and inference for DVARS (Afyouni and Nichols, 2018)
#' 
#' github.com/asoroosh/DVARS
#'
#' @param X a \eqn{T \times N} numeric matrix representing an fMRI run. There should
#'  not be any missing data (\code{NA} or \code{NaN}).
#' @param normalize Normalize the data as proposed in the original paper? Default:
#'  \code{TRUE}. Normalization removes constant-zero voxels, scales by 100 / the
#'  median of the mean image, and then centers each voxel on its mean.
#'
#'  To replicate Afyouni and Nichols' procedure for the HCP MPP data, since the
#'  HCP scans are already normalized to 10,000, just divide the data by 100 and
#'  center the voxels on their means:
#'
#'  \code{Y <- Y/100; DVARS(t(Y - apply(Y, 1, mean)))} where \code{Y} is the 
#'  \eqn{V \times T} data matrix.
#' 
#'  Note that while voxel centering doesn't affect DVARS, it does affect
#'  DPD and ZD.
#' @param cutoff_DVARS,cutoff_DPD,cutoff_ZD Numeric outlier cutoffs. Timepoints
#'  exceeding these cutoffs will be flagged as outliers.
#' @param verbose Should occasional updates be printed? Default is \code{FALSE}.
#'
#' @export
#' @importFrom stats median pchisq qnorm
#' 
DVARS <- function(
  X, normalize=TRUE, 
  cutoff_DVARS=NULL, 
  cutoff_DPD=5,
  cutoff_ZD=qnorm(1 - .05 / nrow(as.matrix(X))),
  verbose=FALSE){

  X <- as.matrix(X)
  T_ <- nrow(X); N_ <- ncol(X)

  cutoff <- list(DVARS=cutoff_DVARS, DPD=cutoff_DPD, ZD=cutoff_ZD)

  if(normalize){
    # Normalization procedure from original DVARS paper and code.
    # Remove voxels of zeros (assume no NaNs or NAs)
    bad <- apply(X == 0, 2, all)
    if(any(bad)){
      if(verbose){ print(paste0('Zero voxels removed: ', sum(bad))) }
      X <- X[,!bad]
      N_ <- ncol(X)
    }
    
    # Scale the entire image so that the median average of the voxels is 100.
    X <- X / median(apply(X, 2, mean)) * 100

    # Center each voxel on its mean.
    X <- t(t(X) - apply(X, 2, mean))
  }

  # compute D/DVARS
  A_3D <- X^2
  Diff <- X[2:T_,] - X[1:(T_-1),]
  D_3D <- (Diff^2)/4
  A <- apply(A_3D, 1, mean)
  D <- apply(D_3D, 1, mean)
  DVARS_ <- 2*sqrt(D) # == sqrt(apply(Diff^2, 1, mean))

  # compute DPD
  DPD <- (D - median(D))/mean(A) * 100

  # compute z-scores based on X^2 dist.
  DV2 <- 4*D # == DVARS^2
  mu_0 <- median(DV2) # pg 305
  sigma_0 <- sd_hIQR(DV2, d=3) # pg 305: cube root power trans
  v <- 2*mu_0^2/sigma_0^2
  X <- v/mu_0 * DV2 # pg 298: ~X^2(v=2*mu_0^2/sigma_0^2)
  P <- pchisq(X, v)
  ZD <- ifelse(
    abs(P-.5)<.49999, # avoid overflow if P is near 0 or 1
    qnorm(1 - pchisq(X, v)), # I don't understand why they use 1-pchisq(X,v) instead of just pchisq(X,v)
    (DV2-mu_0)/sigma_0  # avoid overflow by approximating
  )

  out <- list(
    measure = data.frame(D=c(0,D), DVARS=c(0,DVARS_), DPD=c(0,DPD), ZD=c(0,ZD)),
    measure_info = setNames("DVARS", "type")
  )

  if ((!is.null(cutoff)) || (!all(vapply(cutoff, is.null, FALSE)))) {
    cutoff <- cutoff[!vapply(cutoff, is.null, FALSE)]
    cutoff <- setNames(as.numeric(cutoff), names(cutoff))
    out$outlier_cutoff <- cutoff
    out$outlier_flag <- out$measure[,names(cutoff)]
    for (dd in seq(ncol(out$outlier_flag))) {
      out$outlier_flag[,dd] <- out$outlier_flag[,dd] > cutoff[colnames(out$outlier_flag)[dd]]
    }
    if (all(c("DPD", "ZD") %in% colnames(out$outlier_flag))) {
      out$outlier_flag$Dual <- out$outlier_flag$DPD & out$outlier_flag$ZD
    }
  }

  structure(out, class="clever")
}


# args <- commandArgs(trailingOnly - TRUE)

# X <- args[1]

# dvars <- DVARS(X)
