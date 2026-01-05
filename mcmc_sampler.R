
# gibbs sampler for gas mileage
library("tidyverse"); theme_set(theme_minimal())
library("invgamma")
library("mcmcr")

gibbs_sampler <- function(W, y, groups,
  iter = 10000, burn_in = 5000, thin = 1,
  mu = 25, phi = 4, A_tau = 5, A_sigma = 5, A_gamma = 5){
  
  # lengths
  n_groups <- unique(groups) |> length() # number of cars
  p <- ncol(W) # number of gas stations
  n <- nrow(W) # number of observations
  
  # number of stored iter left after thinning/burn_in
  n_keep <- ceiling((iter - burn_in)/thin)

  # create space for alpha, delta, sigma, theta, gamma, and tau
  alpha_list <- matrix(0, nrow = n_keep, ncol = n_groups)
  delta_list <- matrix(0, nrow = n_keep, ncol = p)
  sigma_list <- rep(0, n_keep)

  theta_list <- rep(0, n_keep)
  gamma_list <- rep(0, n_keep)
  tau_list <- rep(0, n_keep)

  # begin initialization
  
  lambda_tau <- rinvgamma(1, shape = 0.5, rate = 1 / A_tau^2)
  tau_current <- rinvgamma(1, shape = 0.5, scale = 1/ lambda_tau)

  lambda_gamma <- rinvgamma(1, shape = 0.5, rate = 1 / A_gamma^2)
  gamma_current <- rinvgamma(1, shape = 0.5, scale = 1/ lambda_gamma)

  lambda_sigma <- rinvgamma(1, shape = 0.5, rate = 1 / A_sigma^2)
  sigma_current <- rinvgamma(1, shape = 0.5, rate = 1/lambda_sigma)

  theta_current <- rnorm(1, mean = mu, sd = sqrt(phi))
  delta_current <- rnorm(p, 0, sqrt(gamma_current))
  alpha_current <- rnorm(n_groups, theta_current, sqrt(tau_current))

  for(i in 1:iter){

    # draw alpha from full conditional
    for(g in seq_along(unique(groups))){
      y_sub <- y[groups == g]
      W_sub <- W[groups == g,]
      l_alpha <- 1/sigma_current * sum(y_sub - W_sub %*% delta_current) + theta_current/tau_current
      Q_alpha <- length(y_sub)/sigma_current + 1/tau_current
      alpha_current[g] <- rnorm(1, l_alpha/Q_alpha, sd = sqrt(1/Q_alpha))
    }
    alpha <- alpha_current[groups]

    # draw delta from full conditional
    for(j in seq_len(p)){
      w_j <- W[,j]
      W_minus_j <- W[,-j]
      resid_j <- as.vector(y - alpha - W_minus_j%*%delta_current[-j])

      l_delta <- 1/sigma_current * sum(w_j * resid_j)
      Q_delta <- 1/sigma_current * sum(w_j^2) + 1/gamma_current

      delta_current[j] <- rnorm(1, mean = l_delta/Q_delta, sd = sqrt(1/Q_delta))
    }
    # enforce sum to zero constraint on delta
    delta_current <- delta_current - mean(delta_current)

    # draw sigma^2|lambda_sigma
    sse <- sum((y - (alpha + W%*%delta_current))^2)
    sigma_current <- rinvgamma(1, shape = (n + 1)/2, rate = .5*sse + 1/lambda_sigma)
    
    # draw lambda_sigma|sigma^2
    lambda_sigma <- rinvgamma(1, shape = 1, rate = 1/sigma_current + 1/A_sigma^2)

    # draw theta from full conditional
    l_theta <- 1/tau_current*sum(alpha_current) + 1/phi * mu
    Q_theta <- n_groups/tau_current + 1/phi

    theta_current <- rnorm(1, mean = l_theta/Q_theta, sd = sqrt(1/Q_theta))

    # draw tau|lambda_tau
    tau_current <- rinvgamma(1, shape = (n_groups + 1)/2, rate = .5*sum((alpha_current - theta_current)^2) + 1 / lambda_tau)

    # draw lambda_tau|tau
    lambda_tau <- rinvgamma(1, shape = 1, scale = 1/tau_current + 1/A_tau^2)

    # draw gamma|lambda_gamma
    tau_current <- rinvgamma(1, shape = (p + 1)/2, rate = .5*sum(delta_current^2) + 1 / lambda_gamma)

    # draw lambda_gamma|gamma
    lambda_gamma <- rinvgamma(1, shape = 1, scale = 1/gamma_current + 1/A_gamma^2)

    # store parameters
    if(i > burn_in && (i - burn_in) %% thin == 0){
      store_i <- (i - burn_in) / thin # index

      alpha_list[store_i,] <- alpha_current
      delta_list[store_i,] <- delta_current
      sigma_list[store_i] <- sigma_current
      theta_list[store_i] <- theta_current
      gamma_list[store_i] <- gamma_current
      tau_list[store_i] <- tau_current
    }
  }
  colnames(delta_list) <- colnames(W)

    list("alpha" = alpha_list, "delta" = delta_list, "sigma_2" = sigma_list,
      "theta" = theta_list, "gamma" = gamma_list, "tau" = tau_list)
}

