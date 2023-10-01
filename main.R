library(I3HQC)
library(tidyverse)
library(FlowSOM)
library(umap)

###dir_in <- "~/Documents/git/R/Pennsieve_Test/20230503 and 20230504_cleanuptags_50K"
dir_in <- "~/Downloads/VIP2"
###dir_in <- "~/Downloads/AALC_cleanuptags_QC4-6IHgating"

####dir_out <- "~/Documents/git/R/Pennsieve_Test/out"
dir_out <- "~/Downloads/VIP2_results"
###dir_out <- "~/Downloads/AALC_cleanuptags_QC4-6IHgating_results5"

### Read manifest from file (if it exists)
# manifest <- read_csv(paste0(dir_in, "manifest.csv"))

### OR make a bare-bones version on the fly
### NEW: this also pulls day of run from FCS header
manifest <- make_manifest(dir_in, control_pattern = "HD")
manifest
## optional:   manifest <- make_manifest(dir_in)

omiq_key_file <- paste0(dir_in, "/_FilterValuesToNames.csv")
qc_data <- read_data(manifest, omiq_key_file)

### uncomment next line to output cleaned files
# write_CD45_gated_fcs(qc_data, dir_out)

#######################################################
################## Cleanup / beads ####################
### Skip this section if working with cleaned files ###
#######################################################

mmtab <- get_cleanup_table(qc_data)
gtsave(mmtab , filename = paste0(dir_out, "/table.pdf"))


## For Matei, gtsave destroys formatting (color, boldface etc)
## Clumsy workaround: display in Rstudio -> Export -> Save as Web Page
## -> open in browser -> print -> save as pdf
mmtab


## Flag channel/file pairs where acquisition is not stable over time
js_time <- get_js_time(qc_data)
js_time_max <- js_time %>%
  group_by(file, channel) %>%
  summarise(max_js_div = max(js_div))

ggplot(js_time_max, aes(x=file, y=channel, fill=max_js_div)) +
  geom_tile() +
  scale_fill_gradient(low="white", high="red", limits=c(0,1)) +
  theme_bw(base_size=14)

plot_time_outliers(qc_data, js_time_max, dir_out, cutoff=0.05)




#######################################################
################ Univariate Model #####################
#######################################################

hist <- binned_histograms(qc_data)
## ?binned_histograms ## view documentation
## View(binned_histograms) ## examine source code

js <- get_js_hist(hist)
js_score <- average_js_score(js , n_sd_cutoff = 2)
js
js_score
# write_csv(js_score, file=paste0(dir_out, "qc_js_univariate.csv"))  ##optional

plot_js_all(js)
ggsave(paste0(dir_out,"/figures/qc/js_1d.png"), width=12,height=11)

plot_js_control(js, manifest)
ggsave(paste0(dir_out,"/figures/qc/js_1d_control.png"), width=9,height=8)

plot_js_channel(js, "CD4")
ggsave(paste0(dir_out, "/figures/qc/js_CD4.png"), width=9, height=8)

## color by any metadata column
plot_hist_facets_all(hist, js_score, color_col="date")
ggsave(paste0(dir_out,"/figures/qc/univariate_all.png"), width=12, height=8)

plot_hist_facets_control(hist, color_col="file")
ggsave(paste0(dir_out,"/figures/qc/univariate_control.png"), width=12, height=8)


## plots for individual channels, color by any metadata column
channels <- unique(hist$channel)
for (ch in channels) {
  p <- plot_hist_all(hist, ch, color_col="date")
  ggsave(p, filename = paste0(dir_out, "/figures/kdes_all/", ch, ".png"),
         width=12, height=7)

  p <- plot_hist_control(hist, ch, color_col="file")
  ggsave(p, filename = paste0(dir_out, "/figures/kdes_control/", ch, ".png"),
         width=12, height=7)
}


##### gets rid of something that came from an error before###  rm(ch)

#######################################################
############## Multivariate Model #####################
#######################################################

cols_clustering <- c("CD3", "CD4", "CD8a", "CD20", "CD11c", "CD294",
                     "CD66b", "CD56", "CD123", "TCRgd", "CD38")
data_clustering <- qc_data$data[,cols_clustering]

set.seed(0)
som <- SOM(data_clustering, xdim=10, ydim=10)  #default xdim ydim

set.seed(0)
metaclusters <- metacluster_som(qc_data$data, som, k=10)
clustering <- metaclusters$clustering
centroids <- metaclusters$centroids

pheatmap::pheatmap(centroids)


### Visualize

set.seed(0)
sel_umap <- sample(nrow(data_clustering), 5e4) #50K cells subsampling to run in <10 min
um <- umap(data_clustering[sel_umap,])


dim_red <- as_tibble(qc_data$data[sel_umap,]) %>%
  mutate(umap1 = um$layout[,1],
         umap2 = um$layout[,2],
         cluster = clustering[sel_umap],
         file_id = as.double(qc_data$file_array[sel_umap])) %>%
  inner_join(qc_data$manifest)

plot_umap_discrete(dim_red, "cluster", "Cell Type")
ggsave(filename=paste0(dir_out,"/figures/umap/clustering.png"), width=9, height=7)

plot_umap_discrete(dim_red, "control", "Control cells")
ggsave(filename=paste0(dir_out,"/figures/umap/control.png"), width=9, height=7)


for (m in colnames(qc_data$data)) {
  p <- plot_umap_continuous(dim_red, m, m)
  ggsave(p, filename=paste0(dir_out,"/figures/umap/channel_", m, ".png"),
         width=9, height=7)
}


feat <- features_multivariate(qc_data$file_array, clustering, manifest)
labels <- levels(clustering) ##### 05.31: added this line to fix error
feat_tall <- feat %>%
  pivot_longer(all_of(labels),
               names_to="cell_type",
               values_to="fraction")

ggplot(feat_tall %>% filter(control),  ##remove filter control for the rest of the samples
       aes(fill=as.factor(file), x=fraction, y=factor(file, levels=rev(levels(factor(file)))))) +
  geom_col(position="dodge") +
  facet_wrap(~cell_type, scales="free_x") +
  scale_y_discrete(name="Filename") +
  theme_bw()
ggsave(paste0(dir_out,"/figures/qc/cluster_perc_control.png"), width=9, height=7)


feat_cv <- feat_tall %>%
  filter(control) %>%
  group_by(cell_type) %>%
  summarise(Mean = mean(fraction),
            SD = sd(fraction)) %>%
  mutate(CV = SD/Mean)
ggplot(feat_cv, aes(y=cell_type, x=CV)) +
  geom_col(fill="#00BFC4") +
  ylab("Cell Type") +
  geom_vline(xintercept=0.25, linetype="dashed") +
  theme_bw(base_size=16)
ggsave(paste0(dir_out,"/figures/qc/cluster_CV.png"), width=9, height=7)


###########################################
################ EMD ######################
###########################################

emd <- get_emd(qc_data$file_array, som$mapping[,1], som$codes)

set.seed(0)
umap_emd <- compute_umap_dist(emd, unique(qc_data$file_array),
                              inner_join(manifest, js_score), n_neighbors = 7)

plot_umap_emd(umap_emd) +
  ggtitle("UMAP of EMD distance between samples")
ggsave(paste0(dir_out,"/figures/qc/umap_emd_all_cells.png"), width=9, height=7)



###########################################
################ EMD not neutro ###########
###########################################

not_neutro <- which(metaclusters$metacl != "Neutrophils")
emd_not_neutro <- get_emd(qc_data$file_array, som$mapping[,1], som$codes, keep=not_neutro)

set.seed(0)
umap_emd_not_neutro <- compute_umap_dist(emd_not_neutro, unique(qc_data$file_array),
                                         inner_join(manifest, js_score), n_neighbors = 7)

plot_umap_emd(umap_emd_not_neutro, color_col = "date") +
  ggtitle("UMAP of EMD distance between samples; granulocytes excluded")
ggsave(paste0(dir_out,"/figures/qc/umap_emd_no_neturophils.png"), width=9, height=7)

