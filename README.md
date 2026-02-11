# The relativity of hydrologic stress

An interactive R Shiny toy model for exploring the statistical properties of **hydrologic stress** as defined by Nathan et al. (2019).

This tool shows that "stress" is not simply a measure of physical flow alteration — it is a statistical relationship between the magnitude of alteration and the natural variability of the system over a specific timeframe.

## Overview

Nathan et al. (2019) suggest one way to calculate hydrological "stress" from flow alteration is to compare the distribution of system behaviour under baseline conditions against altered conditions:

> The key concept involved is to characterise "hydrologic stress" relative to the range of behaviour encountered under baseline conditions [...] If the range of future behaviour lies largely within the range encountered under baseline conditions, then it can be concluded that the additional stress on the system due to climate change is low.

However, implementations of Nathan et al.'s "stress score" (e.g. John et al., 2023; Morden et al., 2025) often apply a sliding window to calculate the relevant indicator of hydrological alteration (e.g. mean annual flows) through time. This introduces a statistical artefact that this model explores: **window dependency**.

## Window dependency

Users must be aware of a critical mathematical property of this score: **the stress score is dependent on the sample size (window length) used to calculate the flow metric.**

Because this method relies on the overlap of probability distributions, the Central Limit Theorem dictates that increasing the sample size will reduce the variance of the sampling distribution (standard error scales as $1/\sqrt{n}$), even if the underlying physical signal remains constant.

| Window length | Variance (noise) | Distribution overlap | Stress score |
| :--- | :--- | :--- | :--- |
| **Short** (e.g. 5 years) | Higher | Higher | Lower |
| **Long** (e.g. 30 years) | Lower | Lower | Higher |

**The result:** If you change the rolling window from 5 years to 30 years, the stress score will rise even if the flow alteration (the withdrawal) remains exactly the same. You are not changing the river — you are changing the statistical lens. This is a signal processing question, not a magnitude of impact question.

### Literature context

Studies using this metric must align the window length with a biological or engineering reality, rather than choosing it arbitrarily.

**Nathan et al. (2019)** explicitly note the need for a "characteristic period":

> The relevant period for some short-lived fish might be 1 year while that for long-lived fish, or riparian wetland systems, may be 15 years or longer.

**John et al. (2023)** mathematically confirm the impact of shorter windows:

> Metrics calculated over shorter hydroclimatic sequences are inherently more variable than those calculated over longer sequences [...] This suggests that a larger climate-induced change may be required for shorter sequences before the signal becomes dominant.

## Using the model

### The "ghosting" comparison

This feature allows you to visualise the sensitivity of the stress score to the window length.

1. Set the **Rolling Window** to **5 years** (high variability).
2. Click **Ghost Current View**. A dashed line will freeze this "high noise" state.
3. Move the **Rolling Window** to **30 years**.
4. **Compare:** Observe how the solid lines (30-year) narrow and pull apart compared to the ghosted lines (5-year). The jump in the stress score quantifies exactly how much of the "impact" was previously hidden by noise.

## Technical implementation

The simulation generates synthetic river data using an additive noise model with linear non-stationarity.

### Flow generation

The "baseline" and "post-withdrawal" time series are constructed as:

$$Q_{\text{nat}}(t) = \mu_{\text{base}} + (\text{Trend} \times t) + \text{Noise}(t)$$

$$Q_{\text{post}}(t) = Q_{\text{nat}}(t) - \text{Gap}$$

where:

- **Base flow** ($\mu_{\text{base}}$) — fixed at 60 units.
- **Trend** — linear gain or loss (−0.5 to +0.5 units/month) representing non-stationarity (e.g. climate drying or wetting).
- **Gap** — constant subtraction representing the signal (human withdrawal).

### The noise function

The noise term $\text{Noise}(t)$ is generated to ensure statistical control. Regardless of the chosen distribution shape, the noise is centred and scaled to match the user-defined sigma ($\sigma$):

$$\text{Noise} = (X - \bar{X}) \times \frac{\sigma}{\text{sd}(X)}$$

This ensures that changing the distribution *shape* does not accidentally change the *magnitude* of the variance, allowing for a fair comparison of how skewness affects signal detection.

### Available distributions

Users can toggle the underlying probability distribution of the noise to test robustness:

- **Normal (Gaussian)** — symmetric noise; the baseline for standard signal processing.
- **Log-normal** — right-skewed; representative of real-world river flows where flows cannot be negative but can have high outliers.
- **Weibull** — simulates regimes driven by extreme events or "fat tails."

## Metric definitions

- **Overlap (noise)** — the area shared by the baseline and impacted distributions. An overlap of 1.0 indicates the impact is indistinguishable from natural variability.
- **Stress score (signal)** — calculated as $1 - \text{Overlap}$ (signed by direction of change). A score of $\pm 1.0$ means the future regime is entirely novel — a "new normal" completely outside the historical range.

## References

- [Nathan, R.J. et al. (2019). Assessing the degree of hydrologic stress due to climate change. *Climatic Change*, 156(1–2):87–104.](https://doi.org/10.1007/s10584-019-02497-4)
- [John, A. et al. (2023). The time of emergence of climate-induced hydrologic change in Australian rivers. *Journal of Hydrology*, 619:129371.](https://doi.org/10.1016/j.jhydrol.2023.129371)
- [Morden, R. et al. (2025). Mitigating impacts of climate change on flow regimes through management of small dams and abstractions. *Journal of Hydrology*, 661:133583.](https://doi.org/10.1016/j.jhydrol.2025.133583)