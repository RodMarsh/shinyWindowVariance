library(shiny)

# --- UI ---
ui <- fluidPage(
  titlePanel("Window length influence on stress score"),
  
  sidebarLayout(
    sidebarPanel(
      tabsetPanel(
        tabPanel("Parameters",
          br(),
          numericInput("samples", "Record length (months): affects precision, not averaging variance", value = 1200, min = 100, step = 100),
          sliderInput("gap", "Withdrawal signal (gap)", min = 0, max = 10, value = 0.5, step = 0.5),
          sliderInput("noise", "Noise magnitude (sigma)", min = 1, max = 30, value = 15),
          sliderInput("trend", "Annual trend (gain/loss)", min = -0.02, max = 0.02, value = 0.0, step = 0.002)
        ),
        tabPanel("Distributions",
          br(),
          selectInput("dist_type", "Noise distribution",
                      choices = c("Normal" = "norm", "Log-Normal" = "lnorm", "Weibull" = "weibull"),
                      selected = "lnorm"),
          checkboxInput("detrend", "Remove trend", value = FALSE)
        )
      ),
      hr(),
      selectInput("window", "Rolling window (years): changes averaging variance (σ)", choices = c(5, 10, 20, 30), selected = 5),
      
      actionButton("save_shadow", "Ghost current view", icon = icon("ghost"), class = "btn-info"),
      actionButton("clear_shadow", "Clear ghosts", icon = icon("trash")),
      
      hr(),
      tags$a(href = "https://github.com/RodMarsh/shinyWindowVariance", 
             "View Documentation (README)", 
             target = "_blank", 
             style = "font-weight: bold; color: #337ab7;")
             
    ),
    
    mainPanel(
      plotOutput("timePlot", height = "300px"),
      plotOutput("distPlot", height = "500px"),
      h4("Stress vs window length"),
      uiOutput("summaryTable")
    )
  )
)

# --- Server ---
server <- function(input, output, session) {
  
  # Store Ghost Data
  v <- reactiveValues(
    shadow_dens_nat = NULL,
    shadow_dens_post = NULL,
    shadow_metrics = NULL,
    shadow_win = NULL
  )
  
  manual_roll <- function(x, k) {
    as.numeric(stats::filter(x, rep(1/k, k), sides = 1))
  }
  
  # 2. Data Generation
  data_gen <- reactive({
    set.seed(42)
    n <- input$samples
    t <- 1:n
    
    # Generate noise
    noise_raw <- switch(input$dist_type,
      "norm"    = rnorm(n, 0, input$noise),
      "lnorm"   = { 
        d <- rlnorm(n, 0, 0.5)
        (d - mean(d)) * (input$noise / sd(d)) 
      },
      "weibull" = { 
        d <- rweibull(n, 1.5, 1)
        (d - mean(d)) * (input$noise / sd(d)) 
      }
    )
    
    # Trend logic
    current_trend <- if(input$detrend) 0 else input$trend
    monthly_trend <- current_trend / 12
    natural <- 60 + (monthly_trend * t) + noise_raw
    post <- natural - input$gap
    
    list(Month = t, Natural = natural, Post = post)
  })
  
  # 3. Process monthly series, annual means, then rolling means (in years)
    processed <- reactive({
      d <- data_gen()

      # Annual aggregation from monthly series
      yearIndex <- floor((d$Month - 1) / 12) + 1
      natAnnual <- as.numeric(tapply(d$Natural, yearIndex, mean))
      postAnnual <- as.numeric(tapply(d$Post, yearIndex, mean))

      # Rolling window in years (one value per year)
      wYears <- as.numeric(input$window)
      natRoll <- manual_roll(natAnnual, wYears)
      postRoll <- manual_roll(postAnnual, wYears)

      # Valid years after rolling window fills
      validIdx <- !is.na(natRoll)

      # Month positions for each annual point (end of each year)
      yearCount <- length(natAnnual)
      yearEndMonth <- seq_len(yearCount) * 12

      list(
        # Monthly series (for the noisy background)
        Month = d$Month,
        Natural = d$Natural,
        Post = d$Post,

        # Annual series (one value per year)
        Year = seq_len(yearCount),
        YearEndMonth = yearEndMonth,
        NatAnnual = natAnnual,
        PostAnnual = postAnnual,

        # Rolling annual means (aligned to Year / YearEndMonth)
        Nat_Roll = natRoll,
        Post_Roll = postRoll,
        ValidIdx = validIdx
      )
    })

  # 4. Metric calculation (overlap, stress, decomposition, Kuiper V)
  calc_metrics <- function(nat, post) {
      nat <- nat[is.finite(nat)]
      post <- post[is.finite(post)]

      # Overlap & stress
      x_range <- range(c(nat, post))
      from <- x_range[1] - 10
      to <- x_range[2] + 10

      d1 <- density(nat, from = from, to = to, n = 512)
      d2 <- density(post, from = from, to = to, n = 512)

      dx <- d1$x[2] - d1$x[1]
      overlap_area <- sum(pmin(d1$y, d2$y)) * dx

      direction <- if (median(post) < median(nat)) -1 else 1
      stress <- (1 - overlap_area) * direction

      # Decomposition
      delta <- median(post) - median(nat)
      sigma <- sd(nat)
      delta_sigma <- if (sigma > 0) delta / sigma else NA

      # Kuiper V (descriptive, no p-value)
      xGrid <- sort(unique(c(nat, post)))
      F1 <- ecdf(nat)(xGrid)
      F2 <- ecdf(post)(xGrid)
      Dplus <- max(F1 - F2)
      Dminus <- max(F2 - F1)
      kuiper_v <- Dplus + Dminus

      list(
        overlap = round(overlap_area, 3),
        stress = round(stress, 3),
        delta = round(delta, 3),
        sigma = round(sigma, 3),
        delta_sigma = round(delta_sigma, 3),
        kuiper_v = round(kuiper_v, 3)
      )
    }

  # 5. Ghosting logic
  observeEvent(input$save_shadow, {
      d <- processed()

      nat <- d$Nat_Roll[d$ValidIdx]
      post <- d$Post_Roll[d$ValidIdx]

      metrics <- calc_metrics(nat, post)

      v$shadow_dens_nat <- density(nat)
      v$shadow_dens_post <- density(post)
      v$shadow_metrics <- metrics
      v$shadow_win <- input$window
    })
  
  observeEvent(input$clear_shadow, {
    v$shadow_dens_nat <- NULL
    v$shadow_dens_post <- NULL
    v$shadow_metrics <- NULL
    v$shadow_win <- NULL
  })

  # 6. Base R time plot
  output$timePlot <- renderPlot({
      d <- processed()

      yAll <- range(
        c(d$Natural, d$Post, d$NatAnnual, d$PostAnnual, d$Nat_Roll, d$Post_Roll),
        na.rm = TRUE
      )

      par(mar = c(4, 4, 2, 1))
      plot(d$Month, d$Natural, type = "n",
          ylim = yAll,
          ylab = "Flow volume", xlab = "Month",
          main = "Monthly flows with annual rolling mean")

      # Monthly noise (faint)
      lines(d$Month, d$Natural, col = adjustcolor("blue", alpha.f = 0.15))
      lines(d$Month, d$Post, col = adjustcolor("orange", alpha.f = 0.15))

      # Annual rolling mean (bold), positioned at end-of-year months
      xRoll <- d$YearEndMonth[d$ValidIdx]
      lines(xRoll, d$Nat_Roll[d$ValidIdx], col = "blue", lwd = 2)
      lines(xRoll, d$Post_Roll[d$ValidIdx], col = "orange", lwd = 2)

      legend("topleft", legend = c("Baseline", "Post-withdrawal"),
            col = c("blue", "orange"), lwd = 2, bty = "n")
    })

  # 7. Base R distribution plot
  output$distPlot <- renderPlot({
  d <- processed()

    nat <- d$Nat_Roll[d$ValidIdx]
    post <- d$Post_Roll[d$ValidIdx]

    # Calculate current densities
    d_nat <- density(nat)
    d_post <- density(post)
    
    d_post_interp <- approx(d_post$x, d_post$y, xout = d_nat$x, rule = 2)$y
    system_y <- (d_nat$y + d_post_interp) / 2
    
    # Determine Plot Limits (Include Ghost if present)
    y_max <- max(d_nat$y, d_post$y, system_y)
    x_lims <- range(c(d_nat$x, d_post$x))
    
    if(!is.null(v$shadow_dens_nat)) {
      y_max <- max(y_max, v$shadow_dens_nat$y, v$shadow_dens_post$y)
      x_lims <- range(c(x_lims, v$shadow_dens_nat$x))
    }
    
    # Setup canvas
    par(mar = c(5, 4, 4, 2) + 0.1)
    plot(NA, xlim = x_lims, ylim = c(0, y_max * 1.1), 
         xlab = "Volume", ylab = "Density", main = "", axes = FALSE)
    axis(1); axis(2); box()
    title(main = "Distribution overlap", font.main = 1)
    
    # --- Draw ghost (if exists) ---
    if(!is.null(v$shadow_dens_nat)) {
      lines(v$shadow_dens_nat, col = "blue", lty = 2, lwd = 1)
      lines(v$shadow_dens_post, col = "orange", lty = 2, lwd = 1)
    }
    
    # --- Draw current ---
    # Filled areas
    polygon(d_nat, col = adjustcolor("blue", alpha.f = 0.2), border = "blue")
    polygon(d_post, col = adjustcolor("orange", alpha.f = 0.2), border = "orange")
    
    # System profile line (black)
    #lines(d_nat$x, system_y, col = "black", lwd = 2.5)
    
    # --- Annotations (in box) ---
    curr_metrics <- calc_metrics(nat, post)
    
    # Text construction
    ds_label <- if (is.na(curr_metrics$delta_sigma)) "NA" else curr_metrics$delta_sigma
    txt_curr <- paste0("Current (", input$window, "yr):\n",
                       "  \u0394 (shift): ", curr_metrics$delta, "\n",
                       "  \u03c3 (baseline SD): ", curr_metrics$sigma, "\n",
                       "  \u0394/\u03c3: ", ds_label, "\n",
                       "  Overlap: ", curr_metrics$overlap, "\n",
                       "  Stress:  ", curr_metrics$stress, "\n",
                       "  Kuiper V: ", curr_metrics$kuiper_v, " (shape metric)")

    txt_final <- txt_curr
    if(!is.null(v$shadow_win)) {
      ghost_ds <- if (is.na(v$shadow_metrics$delta_sigma)) "NA" else v$shadow_metrics$delta_sigma
      txt_ghost <- paste0("\n\nGhost (", v$shadow_win, "yr):\n",
                          "  \u0394 (shift): ", v$shadow_metrics$delta, "\n",
                          "  \u03c3 (baseline SD): ", v$shadow_metrics$sigma, "\n",
                          "  \u0394/\u03c3: ", ghost_ds, "\n",
                          "  Overlap: ", v$shadow_metrics$overlap, "\n",
                          "  Stress:  ", v$shadow_metrics$stress, "\n",
                          "  Kuiper V: ", v$shadow_metrics$kuiper_v, " (shape metric)")
      txt_final <- paste0(txt_curr, txt_ghost)
    }
    
    legend("topright", legend = strsplit(txt_final, "\n")[[1]], 
           bty = "o", bg = "white", cex = 1.0, adj = 0)
    
    legend("topleft", legend = c("Baseline", "Post-withdrawal", "Ghost (previous)"),
           fill = c(adjustcolor("blue", 0.2), adjustcolor("orange", 0.2), NA, NA),
           border = c("blue", "orange", NA, NA),
           lwd = c(NA, NA, 1), lty = c(NA, NA, 2), col = c(NA, NA, "black"),
           bty = "n")
  })

  # 8. Stress vs window length summary table
  output$summaryTable <- renderUI({
    d <- data_gen()

    # Annual aggregation (shared across all windows)
    yearIndex <- floor((d$Month - 1) / 12) + 1
    natAnnual <- as.numeric(tapply(d$Natural, yearIndex, mean))
    postAnnual <- as.numeric(tapply(d$Post, yearIndex, mean))

    windows <- c(5, 10, 20, 30)
    rows <- lapply(windows, function(w) {
      natRoll <- manual_roll(natAnnual, w)
      postRoll <- manual_roll(postAnnual, w)
      valid <- !is.na(natRoll)
      nat <- natRoll[valid]
      post <- postRoll[valid]
      calc_metrics(nat, post)
    })

    # Build HTML table using Shiny tags
    header_row <- tags$tr(
      tags$th("Window"),
      tags$th(HTML("&Delta;")),
      tags$th(HTML("&sigma; (per window)")),
      tags$th(HTML("&Delta;/&sigma;")),
      tags$th("Overlap"),
      tags$th("Stress"),
      tags$th("Kuiper V")
    )

    body_rows <- lapply(seq_along(windows), function(i) {
      m <- rows[[i]]
      ds <- if (is.na(m$delta_sigma)) "NA" else format(m$delta_sigma, digits = 3)
      tags$tr(
        tags$td(paste0(windows[i], " yr")),
        tags$td(format(m$delta, digits = 3)),
        tags$td(format(m$sigma, digits = 3)),
        tags$td(ds),
        tags$td(format(m$overlap, digits = 3)),
        tags$td(format(m$stress, digits = 3)),
        tags$td(format(m$kuiper_v, digits = 3))
      )
    })

    tags$table(class = "table table-striped table-hover table-bordered",
      tags$thead(header_row),
      tags$tbody(body_rows)
    )
  })
}

shinyApp(ui, server)