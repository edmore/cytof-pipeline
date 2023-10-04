library(I3HQC)
library(tidyverse)

args <- commandArgs(trailingOnly = TRUE)

if (!length(args)==2) {
  stop("Please provide two arguments: input and output directory.")
} else {
  dir_in <- args[1]
  dir_out <- args[2]
}

# dir_in <- "~/Documents/git/R/IH_VIP_test/20230503 and 20230504_cleanuptags_50K/"
# dir_out <- "~/Documents/git/R/IH_VIP_test/out/"

manifest <- make_manifest(dir_in, control_pattern = "HD")
qc_data <- read_data(manifest)

#######################################################
################## Cleanup / beads ####################
### Skip this section if working with cleaned files ###
#######################################################

df_cleanup <- get_cleanup_table(qc_data)
write_csv(df_cleanup, file = paste0(dir_out, "/cleanup.csv"))

## Flag channel/file pairs where acquisition is not stable over time
js_time <- get_js_time(qc_data)
js_time_max <- js_time %>%
  group_by(file, channel) %>%
  summarise(max_js_div = max(js_div))

plot_time_outliers(qc_data, js_time_max, cutoff=0.05, dir_out=dir_out)

# Save clean files, without debris, beads etc
write_CD45_gated_fcs(qc_data, dir_out)

#######################################################
################ Univariate Model #####################
#######################################################

hist <- binned_histograms(qc_data)
js <- get_js_hist(hist)
js_score <- average_js_score(js, cutoff=0.1)
hist_js <- inner_join(hist, js_score)
write_csv(js_score, file=paste0(dir_out, "qc_js_univariate.csv"))

plot_js_all(js)
ggsave(paste0(dir_out,"figures/qc/js_1d.png"), width=12,height=11)

plot_js_control(js, manifest)
ggsave(paste0(dir_out,"figures/qc/js_1d_control.png"), width=9,height=8)

plot_js_channel(js, "CD4")
ggsave(paste0(dir_out, "figures/qc/js_CD4.png"), width=9, height=8)

## color by any metadata column
plot_hist_facets_all(hist_js, color_col="qc_pass")
ggsave(paste0(dir_out,"figures/qc/univariate_all.png"), width=12, height=8)

plot_hist_facets_control(hist_js, color_col="qc_pass")
ggsave(paste0(dir_out,"figures/qc/univariate_control.png"), width=12, height=8)


## plots for individual channels, color by any metadata column
channels <- unique(hist$channel)
for (ch in channels) {
  p <- plot_hist_all(hist_js, ch, color_col="qc_pass")
  ggsave(p, filename = paste0(dir_out, "figures/kdes_all/", ch, ".png"),
         width=12, height=7)

  p <- plot_hist_control(hist_js, ch, color_col="qc_pass")
  ggsave(p, filename = paste0(dir_out, "figures/kdes_control/", ch, ".png"),
         width=12, height=7)
}


