# GasMileage

For a long time, I've been interested in determining if gas stations produce meaningfull differences in gas quality. Everyone seems to have their own opinion, so I decided to collect data from my own gas filling and driving endeavors for the past few years. For two vehicles, a Hyundai Elantra and Honda CRV, I observe the mileage, gallons of gas, and type of gas for each trip.

Of course, each trip does not empty a tank of gas entirely. Assuming the gasoline from each station is uniformly burned by each vehicle, the proportion of gas from each station is able to obtained. For example, suppose the Elantra's tank is filled completely with gas from Valero. If 1/2 of the tank is emptied and replaced with gas from Exxon, the tank is now composed equally of Valero and Exxon. If 1/2 of the tank is emptied again and replaced with gas from Chevron, then the tank is composed of 1/2 Chevron gas, 1/4 Exxon gas, and 1/4 Valero gas.

I leverage the tank composition to infer the changes in miles per gallon for different gas stations. Admittedly, there are many other factors that determine a vehicles' miles per gallon. The weather, vehicle speed, and road conditions all play enormous roles. These are much too difficult to track, so I make the large assumption that these factors occur independent of the tank's composition. This is an unavoidable, albeit potentially problematic, assumption.

I model the vehicles miles per gallon with a normal-normal hierarchical Bayesian model. The miles per gallon on a single trip for vehicle $i$ is distributed with normal errors:
$$y_i | \alpha, \delta, \sigma^2, W_i \sim N(\alpha_i + W_i^T \delta, \sigma^2),$$
where $\sigma^2$ is the variance, $\alpha_i$ is the vehicle-level coefficient, $\delta$ is the gas station-level coefficient vector, and $W_i$ is the car's tank composition. I place normal priors on both coefficients:
$$\alpha_i|\theta, \tau \sim N(\theta, \tau), \\
    \delta_j| \gamma \sim N(0, \gamma),$$
where $theta$ is the vehicle's prior mean, $\tau$ is the vehicle's prior variance, and $\gamma$ is the gas station's prior variance for the $j = 1, \ldots, p$ gas stations. To account for the uncertainty of $\theta$, I place another normal prior on $\theta$:
$$\theta| \mu, \phi \sim N(\mu, \phi),$$
where the prior mean $\mu$ should be typically fall between 20 and 30 to capture the mpg of a typical vehicle and the variance $\phi$ reflects the uncertainty of this estimate. I also place hierarchical half-Cauchy prior distributions on the variance parameters (Gelman, 2006):
$$\sigma^2| \lambda_{\sigma} \sim \text{Half-Cauchy}(0, \lambda_{\sigma}), \\
    \tau | \lambda_{\tau} \sim \text{Half-Cauchy}(0, \lambda_{\tau}), \\
    \gamma | \lambda_{\gamma} \sim \text{Half-Cauchy}(0, \lambda_{\gamma}).$$
These Half-Cauchy distributions can be easily expressed as Inverse-Gamma distributions to enable efficient posterior sampling with a standard Gibbs sampler.

