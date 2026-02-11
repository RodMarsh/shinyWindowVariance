# The relativity of hydrologic stress

An interactive R Shiny toy model for exploring the concept of **hydrologic stress** as defined by Nathan et al. (2019).

This toy model shows how "stress" is not simply a measure of flow alteration — it is a statistical relationship between the magnitude of alteration and the natural variability of the system over a specific timeframe.

## Window dependency

Users must understand a mathematical property of this metric: **the stress score is dependent on the rolling window length.**

Because this method relies on the overlap of probability distributions, increasing the window length will reduce the variance of the distributions:

| Window length | Variance | Distribution overlap | Stress score |
|:---|:---|:---|:---|
| Short (e.g. 5 years) | High | High | Low |
| Long (e.g. 30 years) | Low | Low | High |

> **Result:** If you change the window from 5 years to 30 years, the stress score will rise even if the flow alteration remains exactly the same. You are not changing the magnitude of flow alteration — you are changing the statistical lens.

Studies using Nathan et al.'s stress score should be aware of the impact of window length choices over stress score results. Nathan et al. note:

> The first aspect of key importance is the typical time period—here termed “characteristic 126 period”—over which a system may be vulnerable to failure […] A water supply that relies on a diversion weir with little storage may be vulnerable to droughts lasting a few weeks or months, whereas a system with a storage capacity able to 129 impound runoff over two or more years will be sensitive to multi-year droughts. […] The relevant period for some short-lived fish might be 1 year while that for long-lived fish, or riparian wetland systems, may be 15 years or longer.

John et al. (2023) build on Nathan et al.'s work and note:

> "Metrics calculated over shorter hydroclimatic sequences are inherently more variable than those calculated over longer sequences, as sampling variability typically decreases with sample size. This suggests that a larger climate-induced change may be required for shorter sequences before the signal becomes dominant.”

This a signal processing question, not a magnitude of impact question. Longer windows increase the effective sample size, reduce variance and make the signal more visible.

## Using the model

Use the sliders to set the variables for your first run.

## The "ghosting" comparison

Use the **Ghost current view** button to visualise the sensitivity of your stress score:

1. Set the window to **5 years** (short-term variability) and ghost this view.
2. Move the window to **30 years** (long-term climate trend).
3. Compare: the jump in stress score shows how much the "stress" metric is dependent on window length.

## Technical implementation

The simulation generates synthetic river data using an additive noise model with linear non-stationarity.

### Flow generation

The "baseline" and "post-withdrawal" time series are constructed as:

$$Q_{\text{baseline}}(t) = \mu_{\text{baseflow}} + (\text{trend} \times t) + \text{noise}(t)$$

$$Q_{\text{post}}(t) = Q_{\text{baseline}}(t) - \text{gap}$$

where:

- **Base flow** ($\mu_{\text{baseflow}}$) is fixed at 60 units.
- **Trend** is a linear gain or loss (−0.5 to +0.5 units/month) representing non-stationarity (e.g. climate drying or wetting).
- **Gap** is a constant subtraction representing the signal (human withdrawal).

### The noise function

The noise term $\text{Nnise}(t)$ is generated to ensure statistical control. Regardless of the chosen distribution shape, the noise is centred and scaled to match the user-defined $\sigma$:

$$\text{noise} = (X - \bar{X}) \times \frac{\sigma}{\text{sd}(X)}$$

This ensures that changing the distribution shape does not accidentally change the magnitude of the variance, allowing for a fair comparison of how skewness affects signal detection.

### Available distributions

Users can toggle the underlying probability distribution of the noise to test robustness:

- **Normal (Gaussian)** — symmetric noise; the baseline for standard signal processing.
- **Log-normal** — right-skewed; representative of real-world river flows where flows cannot be negative but can have high outliers.
- **Weibull** — used to simulate regimes driven by extreme events or "fat tails."

## Metric definitions

- **Overlap (noise)** — the area shared by the baseline and impacted distributions. An overlap of 1.0 indicates the impact is indistinguishable from natural variability.
- **Stress score (signal)** — calculated as $1 - \text{Overlap}$ (signed by direction of change). A score of 1.0 means the future regime is entirely novel — a "new normal" completely outside the historical range.

## References

- Nathan, R.J. et al. (2019). Assessing the degree of hydrologic stress due to climate change. *Climatic Change*, 156(1-2):87-104.
- John, A. et al. (2023). The time of emergence of climate-induced hydrologic change in Australian rivers. *Journal of Hydrology*, 619:129371.
- Morden, R. et al. (2025). Mitigating impacts of climate change on flow regimes through management of small dams and abstractions. *Journal of Hydrology*, 661:133583.