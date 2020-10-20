#' Add numbers only if at least one of them isn't zero or NA
#' If both numbers are zero or NA, return zero
#'
#' @param x First number
#' @param y Second number
#'
#' @examples
#' 1 %++% 1  # == 2
#' 1 %++% NA # == 1
`%++%` = function(x, y) {
  if ( (is.na(x) | x == 0) & (is.na(y) | y == 0) ) {
    0
  } else {
    ifelse(is.na(x), 0, x) + ifelse(is.na(y), 0, y)
  }
}

#' Calculate risk quantiles
#' 
#' @param risk.col The data to quantise
#' @param quants Number of quantiles (default: 5)
#' @param highest.quantile.is.worst Should a risk score of 1 represent the highest/worst number in the data (FALSE) or the lowest/best (FALSE)?
#' @param style Method to use for calculating quantiles (passed to classIntervals; default: Fisher). One of "fixed", "sd", "equal", "pretty", "quantile", "kmeans", "hclust", "bclust", "fisher", "jenks" or "dpih"
#' @param samp_prop The proportion of samples to use, if slicing using "fisher" or "jenks" (passed to classIntervals; default: 100%)
#' @return A vector containing the risk quantiles
#'
calc_risk_quantiles = function(risk.col, quants = 5, highest.quantile.is.worst = TRUE, style = "fisher", samp_prop = 1) {
  if (length(unique(risk.col)) > 1) {  # only calculate quintiles if there are more unique values than quantiles
    
    # calculate the quantile breaks
    q_breaks = classInt::classIntervals(risk.col, quants, style = style, samp_prop = samp_prop, largeN = length(risk.col))
    
    q = as.integer(cut(risk.col, breaks = q_breaks$brks, include.lowest = T))  # create a column with the risk quantiles as a number (e.g. from 1 to 5, if using quintiles)
  
    if (!highest.quantile.is.worst) {
      max_quant = max(q, na.rm = TRUE)  # get the max. quantile in the dataset (won't always be equal to `quants`, e.g. if nrows(d) < quants)
      q = (max_quant + 1) - q  # reverse the quantile scoring so 1 = highest risk
    }
    
    q  # return the quantiles
    
  } else {
    1
  }
}


#' invert deciles
#' @param x Deciles
#' 
reverse_decile = function(x) 11 - x

#' Invert deciles, ranks, percentiles etc.
#' e.g. with decile, a score of 10 --> 1 and score of 1 --> 10
#' @param x Vector of data to invert
invert_this = function(x) (max(x, na.rm = TRUE) + 1) - x

# Wrap long ggplot2 titles
ggplot_title_wrapper <- function(x, ...) 
{
  paste(strwrap(x, ...), collapse = "\n")
}

#########################################################################################################
## functions for calculating the vulnerability index, in the style of the Index of Multiple Deprivation
##

#' Transform data to an exponential distribution
#' using the exponential transformation function listed in Welsh IMD's tech report - see Appendix A: https://gov.wales/sites/default/files/statistics-and-research/2020-02/welsh-index-multiple-deprivation-2019-technical-report.pdf
#'  
#'  @param x The data to transform
#'  
exp_transform = function(x) -23 * log(1 - x * (1 -exp(-100/23)))

#' Normalise ranks to a range between 0 and 1
#' 
#' @param x List of ranks
#' 
scale_ranks = function(x) (x - 1) / (length(x) - 1)

#' Rank indicators but put NAs first (i.e. least-worst)
#' @param x Data to rank
#' 
rank2 = function(x) rank(x, na.last = FALSE)

#' Inverse ranking with NAs first (i.e. 1 = worst)
#' @param x Data to rank
#' 
inverse_rank = function(x) (length(x) + 1) - rank(x, na.last = FALSE)

#' Calculate domain scores, ranks and deciles
#' This function will calculate over all numeric variables in a dataframe
#' 
#' @param d Dataframe containing underlying indicators
#' @param domain Name of the vulnerability domain - if not blank, prepend this string to the vulnerability score/rank/decile columns
#' @param rank.indicators Rank the underlying indicators before calculating scores etc.?
#' @param keep.interim.indicators If TRUE, keep the scores and ranks calculated for each underlying indicator (default: FALSE)
#' @param bespoke.domains If TRUE, ignore the four weights parameters (below) and just add equally across all the variables passed into this function
#' @param clinical_weight Weight (between 0 and 1, inclusive) to assign to clinical vulnerability domain
#' @param health_weight Weight (between 0 and 1, inclusive) to assign to health/wellbeing vulnerability domain
#' @param economic_weight Weight (between 0 and 1, inclusive) to assign to economic vulnerability domain
#' @param social_weight Weight (between 0 and 1, inclusive) to assign to social vulnerability domain
#' 
calc_domain_scores = function(d,
                              domain = NULL,
                              rank.indicators = TRUE,
                              keep.interim.indicators = FALSE,
                              bespoke.domains = FALSE,
                              clinical_weight = 0.25,
                              health_weight = 0.25,
                              economic_weight = 0.25,
                              social_weight = 0.25) {
  
  # Check that weights add to 1. 
  # All weights don't have to be inputted.
  if(sum(clinical_weight,
         health_weight,
         economic_weight,
         social_weight) != 1){
    stop("The supplied weights don't sum to 1!")
  }
  
  if (rank.indicators) {
    d = d %>% 
      mutate_if(is.numeric, list(rank = rank2))  # convert indicators to ranks
  }
  
  d = d %>% 
    # normalise the ranks so they're between 0 and 1
    mutate_at(vars(ends_with("rank")), list(scaled = scale_ranks)) %>% 
    
    # transform to an exponential distribution
    mutate_at(vars(ends_with("scaled")), exp_transform)
  
  # calculate overall domain score
  if (bespoke.domains) {
    # combine with equal weights to get domain score
    d = d %>% 
      mutate(`Vulnerability score` = reduce(select(., ends_with("scaled")), `+`))  # source: https://stackoverflow.com/a/54527609
    
  } else {
    d = d %>% 
      # Add row-wise grouping to sum weighted ranks across rows
      rowwise() %>% 
      
      # combine with equal weights to get domain score
      mutate(`Vulnerability score` = sum(`Clinical Vulnerability rank_scaled` * clinical_weight,
                                         `Health/Wellbeing Vulnerability rank_scaled` * health_weight,
                                         `Economic Vulnerability rank_scaled` * economic_weight,
                                         `Social Vulnerability rank_scaled` * social_weight)) %>%
      # Remove row-wise grouping
      ungroup()
  }

  # calculate domain ranks and deciles
  d = d %>% 
    mutate(`Vulnerability rank` = rank(`Vulnerability score`)) %>% 
    mutate(`Vulnerability decile` = calc_risk_quantiles(`Vulnerability rank`, quants = 10))
  
  if (is.character(domain))
    names(d)[ grepl("^Vulnerability", names(d)) ] = paste(domain, grep("^Vulnerability", names(d), value = T), sep = " ")
  
  if (!keep.interim.indicators)
    # keep only original indicators and domain vulnerability score/rank/decile
    d = d %>% select(-ends_with("_rank"), -ends_with("scaled"))
  
  d
}

# ----- Domain Scores (Weighted Indicators) -----
# Calculate vulnerability domain scores with weighted indicators

# Methodology
# 1. Scale each indicator to Mean = 0, SD = 1
# 2. Perform either PCA or MLFA and extract weights for that domain
#    (use model argument to specify)
# 3. Multiply model weights by respective column to get weighted indicators
# 4. Sum weighted indicators
# 5. Rank and quantise into deciles

# Additional Libraries Required
library(broom)

# Create standardised function that scales each indicator to mean = 0 & SD = 1.
standardised = function(x) (x - mean(x))/sd(x)

# Create weighted domain function
weighted_domain_scores <- function(d,
                                   model = c("PCA", "MLFA"),
                                   domain = NULL,
                                   keep.interim.indicators = FALSE) {
  
  # Rank and normalise indicators to mean 0, SD 1.
  d <- d %>%
    mutate_if(is.numeric, list(scaled = function(x) standardised(rank2(x))))
  
  # Evaluate model choice
  model <- match.arg(model)
  
  # Extract weights
  if(model == "PCA"){
    d_weights <- d %>%
      select(ends_with("_scaled")) %>%
      prcomp(center = FALSE, scale = FALSE) %>%
      pluck("rotation") %>%
      as.data.frame() %>%
      rownames_to_column(var = "variable") %>%
      as_tibble() %>%
      select(variable, weights = PC1) %>%
      mutate(weights = weights^2)
  } else {
    d_weights <- d %>%
      select(ends_with("_scaled")) %>%
      factanal(factors = 1) %>%
      tidy() %>%
      select(-uniqueness, weights = fl1) %>%
      mutate(weights = abs(weights),
             weights = weights/sum(weights))
  }
  
  # Multiply model weights by respective column to get weighted indicators
  d_weighted_ind <- d %>%
    select(d_weights$variable) %>%
    map2_dfc(d_weights$weights, `*`) %>%
    select_all(list(~ str_remove(., "_scaled"))) %>%
    select_all(list(~ str_c(., "_weighted")))
  
  # Combine weighted indicators with original data
  d <- bind_cols(d, d_weighted_ind)
  
  # Sum weighted indicators
  d <- d %>%
    mutate(`Vulnerability score` = reduce(select(., ends_with("_weighted")), `+`))
  
  # Rank and quantise into deciles
  d <- d %>%
    mutate(`Vulnerability rank` = rank(`Vulnerability score`)) %>%
    mutate(`Vulnerability decile` = calc_risk_quantiles(`Vulnerability rank`, quants = 10))
  
  # Add domain prefix if supplied
  if (is.character(domain))
    names(d)[ grepl("^Vulnerability", names(d)) ] = paste(domain, grep("^Vulnerability", names(d), value = T), sep = " ")
  
  # Keep/drop interim indicator
  if (!keep.interim.indicators)
    # keep only original indicators and domain vulnerability score/rank/decile
    d = d %>% select(-ends_with("_scaled"), -ends_with("_weighted"))
  
  # Return data
  return(d)
  
}


# ----- Aggregate Vulnerability Index into higher geographies (e.g. Local Authorities) -----
#' Calculate the Extent and population-weighted average scores for small areas (MSOAs)
#' 
#' "Extent" is the proportion of the local population that live in areas classified as among the most deprived in the higher geography.
#' To calculate this, we need to first calculate a weighted score based on the population in the most deprived 30% of areas
#' 
#' @param d Dataframe containing Vulnerability Index ranks, scores and population estimates
#' @param domain Which Vulnerability domain to calculate population-weighted scores for
#' @param population_col Name of the column containing population estimates
#' @param max_rank Let user set the highest rank of the domain/indicator (defaults to finding max rank in the data)
#' 
pop_weighted_scores = function(d, domain = NULL, aggregate_by, population_col = "No. people", max_rank = NULL) {
  
  rank_col = ifelse(is.null(domain), "Vulnerability rank", paste0(domain, " Vulnerability rank"))
  score_col = ifelse(is.null(domain), "Vulnerability score", paste0(domain, " Vulnerability score"))
  
  if (is.null(max_rank))
    max_rank = max(d[[rank_col]])
  
  d %>% 
    group_by(!!sym(aggregate_by)) %>%
    
    mutate(Percentile = round((!!sym(rank_col) / max_rank) * 100, 0)) %>% 
    
    # invert percentiles because, in the Vulnerability Index, higher percentiles mean higher vulnerability - but the extent score calculation below assumes lower percentiles mean higher vulnerability
    mutate(Percentile = invert_this(Percentile)) %>%
    
    # calculate extent: a weighted score based on the population in the most deprived 30% of areas
    # from the IMD technical report Appendix N:
    # "The population living in the most deprived 11 to 30 per cent of Lower-layer Super Output Areas 
    # receive a sliding weight, ranging from 0.95 for those in the most deprived eleventh percentile, 
    # to 0.05 for those in the most deprived thirtieth percentile. 
    # In practice this means that the weight starts from 0.95 in the most deprived eleventh percentile, 
    # and then decreases by (0.95-0.05)/19 for each of the subsequent nineteen percentiles 
    # until it reaches 0.05 for the most deprived thirtieth percentile, and zero for areas outside the most deprived 30 per cent"
    mutate(Extent = case_when(
      Percentile <= 10 ~ !!sym(population_col),
      Percentile == 11 ~ !!sym(population_col) * 0.95,
      Percentile > 11 & Percentile <= 30 ~ !!sym(population_col) * (0.95 - ((0.9/19) * (Percentile - 11))),
      TRUE ~ 0
    )) %>% 
    
    # calculate population-weighted average scores
    mutate(Score = !!sym(score_col) * !!sym(population_col)) %>% 
    
    ungroup()
}

#' Aggregate Vulnerability Index into higher-level geographies, calculating:
#' - proportion of highly vulnerable areas
#' - extent (proportion of the local population that live the most vulnerable areas)
#' - population-weighted average score
#'
#' @param d Dataframe containing Vulnerability Index ranks, scores and population estimates
#' @param domain Which Vulnerability domain to calculate population-weighted scores for
#' @param aggregate_by Name of the column to use for higher-level aggregation (e.g. "LAD19CD")
#' @param population_col Name of the column containing population estimates
#' @param max_rank Let user set the highest rank of the domain/indicator (defaults to finding max rank in the data)
#'
aggregate_scores = function(d, domain = NULL, aggregate_by, population_col = "No. people", max_rank = NULL) {
  
  decile_col = ifelse(is.null(domain), "Vulnerability decile", paste0(domain, " Vulnerability decile"))
  
  # calculate proportions of highly vulnerable MSOAs in the higher-level geography
  d_props = d %>% 
    # label MSOAs by whether they're in top 20% most-vulnerable then summarise by this label
    mutate(Top20 = ifelse(!!sym(decile_col) >= 9, "Top20", "Other")) %>% 
    janitor::tabyl(!!sym(aggregate_by), Top20) %>% 
    
    # calculate proportion of most deprived LSOAs
    mutate(Proportion = Top20 / (Top20 + Other)) %>% 
    select(!!sym(aggregate_by), Proportion)
  
  # calculate population-weighted scores and extent for the higher-level geography
  d_scores = d %>% 
    pop_weighted_scores(domain, aggregate_by, population_col = population_col, max_rank = max_rank) %>% 
    
    group_by(!!sym(aggregate_by)) %>%
    summarise(Extent = sum(Extent) / sum(!!sym(population_col)),
              Score = sum(Score) / sum(!!sym(population_col)))

  # combine and return all aggregated measures
  left_join(d_props, d_scores, by = aggregate_by)
}
