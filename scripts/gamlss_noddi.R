# Install the gamlss package if not already installed
if (!requireNamespace("gamlss", quietly = TRUE)) {
    install.packages("gamlss")
}
if (!requireNamespace("optparse", quietly = TRUE)) {
    install.packages("optparse")
}
if (!requireNamespace("ggplot2", quietly = TRUE)) {
    install.packages("ggplot2")
}

# Load the gamlss package
library(gamlss)
library(optparse)
library(ggplot2)

# Option list.
option_list <- list(
    make_option(c("-i", "--input"), type = "character", default = NULL,
                help = "Path to input CSV file with data", metavar = "character"),
    make_option(c("-m", "--metric"), type = "character", default = "fa_1fiber",
                help = "Name of the metric column in the data [default= %default]", metavar = "character"),
    make_option(c("-s", "--site"), type = "character", default = FALSE,
                help = "Use the site column in the data (if applicable) for random effects", metavar = "boolean"),
    make_option(c("-o", "--output"), type = "character", default = "./results/",
                help = "Path to output directory where results will be stored [default= %default]", metavar = "character")
)

# Parse command line options.
opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

message("Input file: ", opt$input)
message("Metric: ", opt$metric)
message("Output directory: ", opt$output)

message("Loading data...")
# Load the data.
df <- read.csv(opt$input)

# Do sanity checks that opt$metric, age, sex columns exist in df
required_cols <- c(opt$metric, "age", "sex")
missing_cols <- setdiff(required_cols, names(df))
if (length(missing_cols) > 0) {
    stop(paste("Missing required columns in data:", paste(missing_cols, collapse = ", ")))
}

# Data diagnostics
message("Running data diagnostics...")
message(paste("  - Data rows:", nrow(df)))
message(paste("  - Metric range: [", round(min(df[[opt$metric]], na.rm=TRUE), 4), ",", round(max(df[[opt$metric]], na.rm=TRUE), 4), "]"))
message(paste("  - Age range: [", round(min(df$age, na.rm=TRUE), 2), ",", round(max(df$age, na.rm=TRUE), 2), "]"))
message(paste("  - Missing values in metric:", sum(is.na(df[[opt$metric]]))))
message(paste("  - Infinite values in metric:", sum(is.infinite(df[[opt$metric]]))))
message(paste("  - Zero values in metric:", sum(df[[opt$metric]] == 0, na.rm=TRUE)))
message(paste("  - Negative values in metric:", sum(df[[opt$metric]] < 0, na.rm=TRUE)))

# Remove rows with missing, infinite, or non-positive values
df_clean <- df[!is.na(df[[opt$metric]]) & !is.infinite(df[[opt$metric]]) & df[[opt$metric]] > 0 & 
               !is.na(df$age) & !is.infinite(df$age), ]
message(paste("  - Rows after cleaning:", nrow(df_clean)))

if (nrow(df_clean) < nrow(df)) {
    warning(paste("Removed", nrow(df) - nrow(df_clean), "rows with problematic values"))
    df <- df_clean
}

# Ensure factor terms used in model formulas have at least two levels.
sex_nlevels <- nlevels(factor(df$sex))
if (sex_nlevels < 2) {
    stop("Column 'sex' has fewer than 2 levels after cleaning; factor(sex) cannot be used in the model")
}

message("Fitting GAMLSS model...")
# Fit a GAMLSS model predicting the specified metric as a function of age (cubic spline) (we should iterate over the polynomial degree for each combination)
models <- list()
sbc_values <- c()
prev_model <- NULL
for (deg in 1:3) {
    for (sig_deg in 1:3) {
        message(paste("Trying polynomial degree", deg, "for mu and", sig_deg, "for sigma"))
        
        # Wrap in tryCatch to handle fitting failures gracefully
        model <- tryCatch({
            if (!is.null(prev_model)) {
                gamlss(
                    formula=as.formula(paste(opt$metric, "~ fp(age, npoly=", deg, ") + factor(sex)")),
                    sigma.formula=as.formula(paste("~ fp(age, npoly=", sig_deg, ") + factor(sex)")),
                    family=GG, data=df, control=gamlss.control(n.cyc=200, trace=FALSE), method=mixed(10, 50),
                    mu.start=fitted(prev_model, "mu"), sigma.start=fitted(prev_model, "sigma"), nu.start=fitted(prev_model, "nu")
                )
            } else {
                gamlss(
                    formula=as.formula(paste(opt$metric, "~ fp(age, npoly=", deg, ") + factor(sex)")),
                    sigma.formula=as.formula(paste("~ fp(age, npoly=", sig_deg, ") + factor(sex)")),
                    family=GG, data=df, control=gamlss.control(n.cyc=200, trace=FALSE), method=mixed(10, 50)
                )
            }
        }, error = function(e) {
            message(paste("  WARNING: Model fitting failed:", e$message))
            return(NULL)
        })
        
        if (!is.null(model)) {
            models[[paste0("mu", deg, "_sigma", sig_deg)]] <- model
            sbc_values <- c(sbc_values, model$sbc)
            prev_model <- model
            message(paste("  Model converged. SBC =", round(model$sbc, 2)))
        } else {
            message("  Skipping this model configuration.")
        }
    }
}

# Compare models using SBC and get its index.
idx_best <- which.min(sbc_values)
message(paste("Best model is", names(models)[idx_best], "with SBC =", round(min(sbc_values), 2)))
model <- models[[idx_best]]

# Extract selected fractional polynomial powers from fitted smoothers
extract_fp_info <- function(model, parameter = "mu", variable = "age") {
    sm_all <- getSmo(model, what = parameter, which = 0)
    if (is.null(sm_all) || length(sm_all) == 0) {
        return(NULL)
    }

    sm_class <- sapply(sm_all, class)
    lm_idx <- which(sm_class == "lm")

    if (length(lm_idx) == 0) {
        return(NULL)
    }
    if (length(lm_idx) > 1) {
        warning(paste("Multiple lm smoothers found for", parameter, "- using first"))
    }

    sm <- getSmo(model, what = parameter, which = lm_idx[1])
    if (is.null(sm$power) || length(sm$power) == 0) {
        return(NULL)
    }

    # If multiple lm smoothers exist, keep the one linked to the target variable if possible.
    if (!is.null(sm$model$x.fp)) {
        fp_cols <- ncol(as.matrix(sm$model$x.fp))
        if (!is.null(fp_cols) && fp_cols != length(sm$power)) {
            warning(paste("Potential mismatch in fp basis terms for", parameter))
        }
    }

    powers <- sm$power
    coefs <- sm$coefficients
    beta <- coefs[grep("^x\\.fp", names(coefs))]
    intercept <- unname(coefs["(Intercept)"])

    sm_label <- if (variable %in% all.vars(formula(sm))) {
        paste0("fp(", variable, ")")
    } else {
        "fp term"
    }

    list(
        parameter = parameter,
        smooth_name = sm_label,
        powers = powers,
        beta = beta,
        intercept = intercept
    )
}

format_fp_terms <- function(powers) {
    if (length(powers) == 0) {
        return(character(0))
    }

    terms <- character(length(powers))
    repeat_count <- 1

    for (i in seq_along(powers)) {
        p <- powers[i]
        if (i > 1 && isTRUE(all.equal(p, powers[i - 1]))) {
            repeat_count <- repeat_count + 1
        } else {
            repeat_count <- 1
        }

        if (isTRUE(all.equal(p, 0))) {
            if (repeat_count == 1) {
                terms[i] <- "log(z)"
            } else {
                terms[i] <- paste0("log(z)^", repeat_count)
            }
        } else {
            base_term <- paste0("z^", format(p, trim = TRUE, scientific = FALSE))
            if (repeat_count == 1) {
                terms[i] <- base_term
            } else if (repeat_count == 2) {
                terms[i] <- paste0(base_term, " * log(z)")
            } else {
                terms[i] <- paste0(base_term, " * log(z)^", repeat_count - 1)
            }
        }
    }

    terms
}

format_fp_equation <- function(fp_info, prefix = "eta") {
    if (is.null(fp_info) || length(fp_info$beta) == 0) {
        return(NA_character_)
    }

    terms <- format_fp_terms(fp_info$powers)
    betas <- unname(fp_info$beta)
    n_terms <- min(length(terms), length(betas))

    rhs <- paste(sprintf("%.6f * %s", betas[seq_len(n_terms)], terms[seq_len(n_terms)]), collapse = " + ")
    paste0(prefix, "_", fp_info$parameter, "(age) = ", sprintf("%.6f", fp_info$intercept), " + ", rhs)
}

fp_mu <- extract_fp_info(model, parameter = "mu", variable = "age")
fp_sigma <- extract_fp_info(model, parameter = "sigma", variable = "age")

message("Selected fractional polynomial powers:")
if (!is.null(fp_mu)) {
    message(paste0("  mu: ", paste(format(fp_mu$powers, trim = TRUE), collapse = ", ")))
} else {
    message("  mu: no fp(age, ...) term found")
}

if (!is.null(fp_sigma)) {
    message(paste0("  sigma: ", paste(format(fp_sigma$powers, trim = TRUE), collapse = ", ")))
} else {
    message("  sigma: no fp(age, ...) term found")
}

eq_mu <- format_fp_equation(fp_mu, prefix = "eta")
eq_sigma <- format_fp_equation(fp_sigma, prefix = "eta")

if (!is.na(eq_mu)) {
    message("mu fp equation (z = age/10 unless shift/scale specified in fp):")
    message(paste0("  ", eq_mu))
}
if (!is.na(eq_sigma)) {
    message("sigma fp equation (z = age/10 unless shift/scale specified in fp):")
    message(paste0("  ", eq_sigma))
}

fp_summary <- data.frame(
    parameter = character(0),
    selected_powers = character(0),
    fp_equation = character(0),
    stringsAsFactors = FALSE
)

if (!is.null(fp_mu)) {
    fp_summary <- rbind(
        fp_summary,
        data.frame(
            parameter = "mu",
            selected_powers = paste(format(fp_mu$powers, trim = TRUE), collapse = ","),
            fp_equation = ifelse(is.na(eq_mu), "", eq_mu),
            stringsAsFactors = FALSE
        )
    )
}
if (!is.null(fp_sigma)) {
    fp_summary <- rbind(
        fp_summary,
        data.frame(
            parameter = "sigma",
            selected_powers = paste(format(fp_sigma$powers, trim = TRUE), collapse = ","),
            fp_equation = ifelse(is.na(eq_sigma), "", eq_sigma),
            stringsAsFactors = FALSE
        )
    )
}

# Print the formula of the best model
message("Best model formula:")
print(coef(model, type="all"))

# Save the model to output directory
if (!dir.exists(opt$output)) {
    dir.create(opt$output, recursive = TRUE)
}
saveRDS(model, file = file.path(opt$output, paste0("gamlss_model_",opt$metric,".rds", sep="")))
if (nrow(fp_summary) > 0) {
    write.csv(fp_summary, file = file.path(opt$output, paste0(opt$metric, "_fp_selected_powers.csv", sep="")), row.names = FALSE)
}

# -----------------------------------------------------------------------------
# Plot predicted centiles (age on x, fa on y) overlaid on observed samples
# -----------------------------------------------------------------------------

message("Generating centile plots...")
# Helper: pick reference levels for covariates not of interest (sex/cohort)
sex_ref <- if ("sex" %in% names(df)) {
    levels(factor(df$sex))[1]
} else {
    NA
}

# Create an age grid spanning the 0 - 18 age range.
age_min <- min(df$age, na.rm = TRUE)
age_max <- 18 # Keeping max at 18 to avoid extrapolation
age_grid <- seq(age_min, age_max, length.out = 1000)

# Build newdata for prediction. Use reference levels for sex and cohort.
newdata <- data.frame(age = age_grid)
if (!is.na(sex_ref)) newdata$sex <- sex_ref

# Define centile probabilities to plot (including median)
probs <- c(0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99)

# Compute centiles for each probability across the age grid
# Recompute predictions on the age_grid (not the original df)
preds <- predictAll(model, newdata = newdata, data=df)

# Compute centiles: each column corresponds to a prob, each row to an age in age_grid
cent_mat <- sapply(probs, function(p) {
    qGG(p, mu = preds$mu, sigma = preds$sigma, nu = preds$nu)
})

# Ensure cent_mat has dimensions length(age_grid) x length(probs)
if (!is.matrix(cent_mat)) cent_mat <- matrix(cent_mat, ncol = length(probs))
if (nrow(cent_mat) != length(age_grid)) cent_mat <- t(cent_mat)

# Prepare a long data.frame of centile curves for ggplot
cent_df <- data.frame(
    age = rep(age_grid, times = length(probs)),
    prob = factor(rep(as.character(probs), each = length(age_grid)), levels = as.character(probs)),
    metric = as.vector(cent_mat)
)

# Observed points (use the fa variable from your data)
obs_df <- df

# Make the plot: points + centile lines. Highlight the median (0.5).
plt <- ggplot() +
    geom_point(data = obs_df, aes(x = age, y = obs_df[[opt$metric]]), alpha = 0.35, size = 0.9, color = "grey30") +
    geom_line(data = cent_df, aes(x = age, y = metric, group = prob, color = prob, linetype = prob), linewidth = 1) +
    scale_color_manual(values = c(
        "0.01" = "#d73027", "0.05" = "#fc8d59", "0.1" = "#fdae61",
        "0.25" = "#fee08b", "0.5" = "#3288bd", "0.75" = "#91bfdb",
        "0.9" = "#66c2a5", "0.95" = "#1a9850", "0.99" = "#006837"
    )) +
    scale_linetype_manual(values = c(
        "0.01" = "dashed", "0.05" = "dashed", "0.1" = "dashed",
        "0.25" = "dotdash", "0.5" = "solid", "0.75" = "dotdash",
        "0.9" = "dashed", "0.95" = "dashed", "0.99" = "dashed"
    )) +
    guides(color = guide_legend(title = "Centile"), linetype = "none") +
    labs(x = "Age", y = paste(opt$metric), title = paste("Predicted centiles for", opt$metric, "by age"), subtitle = paste("Reference sex:", sex_ref)) +
    # Set ylimits to 10% lower than min observed and 10% higher than max observed
    coord_cartesian(ylim = c(min(obs_df[[opt$metric]]) * 0.9, max(obs_df[[opt$metric]]) * 1.1))

# Make the median thicker and on top by adding it separately
median_df <- subset(cent_df, prob == "0.5")
plt <- plt + geom_line(data = median_df, aes(x = age, y = metric), color = "#000000", linewidth = 1.5)

# Save the centile data to CSV
# Append "site" or "cohort" to the filename based on the random effect used
if (opt$site == "TRUE") {
    write.csv(cent_df, file = file.path(opt$output, paste0(opt$metric, "_centiles_by_age_site.csv", sep="")), row.names = FALSE)
} else {
    write.csv(cent_df, file = file.path(opt$output, paste0(opt$metric, "_centiles_by_age_cohort.csv", sep="")), row.names = FALSE)
}

# Print and save the plot
print(plt)
if (opt$site == "TRUE") {
    ggsave(filename = file.path(opt$output, paste0(opt$metric, "_centiles_by_age_site.png", sep="")), plot = plt, width = 8, height = 6, dpi = 300)
} else {
    ggsave(filename = file.path(opt$output, paste0(opt$metric, "_centiles_by_age_cohort.png", sep="")), plot = plt, width = 8, height = 6, dpi = 300)
}

# Message to user
message("Saved results to", paste0(opt$output), sep="")