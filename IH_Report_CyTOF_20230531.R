#read in packages

library(ggplot2)
library(readxl)
library(dplyr)
library(ggpubr)
library(RColorBrewer)
library(viridis)
library(cowplot)
library(patchwork)
library(tidyr)
library(stringr)
library(ggsci)
library(magrittr)
library(mblm)
library(rstatix)
library(spdep)
library(psych)
library(ggbeeswarm)
library(umap)
library(reshape2)
library(pheatmap)
library(plotly)


#assign working directory
wd<-"/tmp"

#set your working directory
setwd(wd)

#Read in data
Counts1 <-read.csv("20230531_IH_gating_AALC_IHCV.csv") 

Counts2 <-read.csv("20230531_counts_renamed_with_meta.csv") 

Counts <- Counts1 %>% full_join(Counts2)

Counts <- Counts %>%
  unite(col = IH_status, Disease:Treatment, sep = ".", remove = FALSE, )

#set directory where you want .pdf files of reports to be saved
report_directory <- "/tmp"

##set the report sample!!! this will determine which sample is flagged in the report and...
##will define the filename when the report is saved
report_sample <- "53.T1_Normalized.fcs"

report_Study <- "PREPRO"

#calculate frequencies of interest
Frequencies <- Counts %>%
  mutate(Bcells = TotalCD19B / Mononuclear) %>%
  mutate(Naive_Bcells = NaiveB / TotalCD19B) %>%
  mutate(Memory_Bcells_count = IgDnegMemB + IgDposMemB) %>%
  mutate(Memory_Bcells = Memory_Bcells_count / TotalCD19B) %>%
  mutate(Plasmablasts = Plasmablast / TotalCD19B) %>%
  mutate(Monocytes = TotalMonocyte / Mononuclear) %>%
  mutate(Classical_Monocytes = ClassicalMono / TotalMonocyte) %>%
  mutate(Transitional_Monocytes = TransitionalMono / TotalMonocyte) %>%
  mutate(Nonclassical_Monocytes = NonclassicalMono / TotalMonocyte) %>%
  mutate(Basophils = Basophil / Mononuclear) %>%
  mutate(ILCs = ILC / Mononuclear) %>%
  mutate(NKcells = TotalNK / Mononuclear) %>%
  mutate(Early_NK = EarlyNK / TotalNK) %>%
  mutate(Late_NK = LateNK / TotalNK) %>%
  mutate(DCs = TotalDC / Mononuclear) %>%
  mutate(pDCs = pDC / TotalDC) %>%
  mutate(cDCs = cDC / TotalDC) %>%
  mutate(mDCs = mDC / TotalDC) %>%
  mutate(Tcells = abT / Mononuclear) %>%
  mutate(gd_Tcells = gdT / Mononuclear) %>%
  mutate(MAIT_NKT = MAITNKT / Mononuclear) %>%
  mutate(CD8s = CD8 / abT) %>%
  mutate(CD4s = CD4 / abT) %>%
  mutate(DNTs = DNT / abT) %>%
  mutate(DPTs = DPT / abT) %>%
  mutate(CD8_Naive = CD8Naive / CD8) %>%
  mutate(CD8_EM1 = CD8TEM1 / CD8) %>%
  mutate(CD8_EM1_activated = CD8TEM1_activated / CD8TEM1) %>%
  mutate(CD8_CM = CD8TCM / CD8) %>%
  mutate(CD8_CM_activated = CD8TCM_activated / CD8TCM) %>%
  mutate(CD8_EM3 = CD8TEM3 / CD8) %>%
  mutate(CD8_EM3_activated = CD8TEM3_activated / CD8TEM3) %>%
  mutate(CD8_EM2 = CD8TEM2 / CD8) %>%
  mutate(CD8_EM2_activated = CD8TEM2_activated / CD8TEM2) %>%
  mutate(CD8_EMRA = CD8TEMRA / CD8) %>%
  mutate(CD8_EMRA_activated = CD8TEMRA_activated / CD8TEMRA) %>%
  mutate(CD8_activated = nnCD8_activated / nnCD8) %>%
  mutate(CD4_Naive = CD4Naive / CD4) %>%
  mutate(CD4_EM1 = CD4TEM1 / CD4) %>%
  mutate(CD4_EM1_activated = CD4TEM1_activated / CD4TEM1) %>%
  mutate(CD4_CM = CD4TCM / CD4) %>%
  mutate(CD4_CM_activated = CD4TCM_activated / CD4TCM) %>%
  mutate(CD4_EM3 = CD4TEM3 / CD4) %>%
  mutate(CD4_EM3_activated = CD4TEM3_activated / CD4TEM3) %>%
  mutate(CD4_EM2 = CD4TEM2 / CD4) %>%
  mutate(CD4_EM2_activated = CD4TEM2_activated / CD4TEM2) %>%
  mutate(CD4_EMRA = CD4TEMRA / CD4) %>%
  mutate(CD4_EMRA_activated = CD4TEMRA_activated / CD4TEMRA) %>%
  mutate(CD4_activated = nnCD4_activated / nnCD4) %>%
  mutate(cTfh = nnCD4CXCR5pos / CD4) %>%
  mutate(cTfh_activated = nnCD4CXCR5pos_activated / nnCD4CXCR5pos) %>%
  mutate(Tregs = Treg / CD4) %>%
  mutate(Tregs_activated = Treg_activated / Treg) %>%
  mutate(Th1s = Th1 / CD4) %>%
  mutate(Th1s_activated = Th1_activated / Th1) %>%
  mutate(Th17s = Th17 / CD4) %>%
  mutate(Th17s_activated = Th17_activated / Th17) %>%
  mutate(Th2s = Th2 / CD4) %>%
  mutate(Th2s_activated = Th2_activated / Th2) %>%
  mutate(Granulocytes = Granulocyte / CD45) %>%
  mutate(Neutrophils = Neutrophil / Granulocyte) %>%
  mutate(Eosinophils = Eosinophil / Granulocyte)
  
#select columns of interest (frequencies and metadata)
#can select to exclude activated populations
Frequencies_selected <- Frequencies %>%
  #select(c(1:timepoint, Bcells:Eosinophils)) %>%
  select(-c(Memory_Bcells_count)) %>%
    filter(Study != "IH_control") 
  #select(-c(contains("activated")))



#make the numerical dataframe into a matrix
Frequencies_selected_features <- Frequencies_selected %>% select(c(Bcells:Eosinophils))
Frequencies_selected_metadata <- Frequencies_selected %>% select(-c(Bcells:Eosinophils))

Frequencies.matrix <-as.matrix(Frequencies_selected_features, replace=T)
Frequencies.scale<-scale(Frequencies.matrix)
Frequencies.scale[is.na(Frequencies.scale)] <- 0

#Run a UMAP on scaled data
Frequencies.umap<-umap(Frequencies.scale, pca=100)

#Bind the (1) Row Annotations, (2) SCALED data, (3) UMAP Infoumap layout and row information
Frequencies.combined<-cbind(Frequencies_selected_metadata,Frequencies.scale,Frequencies.umap$layout)

names(Frequencies.combined)[names(Frequencies.combined) == "1"] <- "UMAP1"
names(Frequencies.combined)[names(Frequencies.combined) == "2"] <- "UMAP2"

#Plot it out - R-UNROTATED
UMAP_Frequencies_Study <- ggplot(subset(Frequencies.combined), aes(x=UMAP1,y=UMAP2,color=Study))+
  geom_point(alpha = 0.9, size = 1.8)+
  theme_bw() + theme(legend.position = "bottom") +  
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) + 
  labs(y = "UMAP2") +
  labs(x= "UMAP1") +
  #labs(fill = "Prior SARS-CoV2+") +
  theme(legend.position = "right") +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5)) + 
  ggtitle("Immune Landscape") +
  theme(plot.title = element_text(hjust = 0.5,size = 20, face = "bold")) +
  theme(axis.text.y = element_blank()) + 
  #theme(axis.text.x = element_blank()) + 
  #theme(axis.text.y = element_blank()) + 
  #facet_wrap(~Subject_ID)+
  scale_color_manual(values = c("#CA3433", "#54BEEC", "#0D753B","#FF781F", "#EF4BB5", "#7E42DB", "grey50")) 
  #scale_shape_manual(values = c(1,17,15, 5, 8, 9))
#scale_size_manual(values = c(1,1,1,1,3))+
#coord_fixed(0.7/0.7)
UMAP_Frequencies_Study


#Plot it out - R-UNROTATED
UMAP_Frequencies_IH_status <- ggplot(subset(Frequencies.combined), aes(x=UMAP1,y=UMAP2,color=IH_status))+
  geom_point(alpha = 0.9, size = 1.8)+
  theme_bw() + theme(legend.position = "bottom") +  
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) + 
  labs(y = "UMAP2") +
  labs(x= "UMAP1") +
  #labs(fill = "Prior SARS-CoV2+") +
  theme(legend.position = "right") +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5)) + 
  ggtitle("Immune Landscape") +
  theme(plot.title = element_text(hjust = 0.5,size = 20, face = "bold")) +
  theme(axis.text.y = element_blank()) + 
  theme(axis.text.x = element_blank()) + 
  #theme(axis.text.y = element_blank()) + 
  #facet_wrap(~Subject_ID)+
  scale_color_manual(values = c("#CA3433", "#54BEEC", "#0D753B","#FF781F", "#EF4BB5", "#7E42DB", "grey50")) 
#scale_shape_manual(values = c(1,17,15, 5, 8, 9))
#scale_size_manual(values = c(1,1,1,1,3))+
#coord_fixed(0.7/0.7)
UMAP_Frequencies_IH_status

#Plot it out - R-UNROTATED
UMAP_Frequencies_Disease <- ggplot(subset(Frequencies.combined), aes(x=UMAP1,y=UMAP2,color=Disease))+
  geom_point(alpha = 0.9, size = 1.8)+
  theme_bw() + theme(legend.position = "bottom") +  
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) + 
  labs(y = "UMAP2") +
  labs(x= "UMAP1") +
  #labs(fill = "Prior SARS-CoV2+") +
  theme(legend.position = "right") +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5)) + 
  ggtitle("Immune Landscape") +
  theme(plot.title = element_text(hjust = 0.5,size = 20, face = "bold")) +
  theme(axis.text.y = element_blank()) + 
  theme(axis.text.x = element_blank()) + 
  #theme(axis.text.y = element_blank()) + 
  #facet_wrap(~Subject_ID)+
  scale_color_manual(values = c("#CA3433", "#54BEEC", "#0D753B","#FF781F", "#EF4BB5", "#7E42DB", "grey50")) 
#scale_shape_manual(values = c(1,17,15, 5, 8, 9))
#scale_size_manual(values = c(1,1,1,1,3))+
#coord_fixed(0.7/0.7)
UMAP_Frequencies_Disease


Frequencies_long <- Frequencies_selected %>% pivot_longer(Bcells:Eosinophils, names_to = "parameter", values_to = "percent") 
#put the populations in your desired display order
#endpoints.df_long$parameter <- factor(endpoints.df_long$parameter, levels = c("Lymphocytes", "NK", "Bcells", "Plasmablasts", "Tcells", "CD4_T", "CD4_Naive", "CD8_T", "CD8_Naive", "Granulocytes", "Monocytes", "DC", "Basophils", "Eosinophils"))
#assign artificial zeros (unnecessary since not using log scale below)
Frequencies_long_nonzero <- Frequencies_long %>%  mutate(percent = if_else(percent < 0.0001, as.double(0.0001), percent)) %>%
  filter(IH_status == "healthy.none" | Study == report_Study)

Frequencies_long_nonzero$Study[Frequencies_long_nonzero$Study != report_Study] <- "Healthy"

stat.test_all_parameters_Study  <- Frequencies_long_nonzero %>%
  group_by(parameter) %>%
  wilcox_test(percent ~ Study) %>%
  adjust_pvalue(method = "BH") %>%
  add_significance() %>%
  add_y_position(fun = "max", step.increase = 0) %>%
  mutate(y.position = y.position *1.1)
stat.test_all_parameters_Study

#make the report!
all_parameters_Study <- ggplot(Frequencies_long_nonzero, aes(x = Study, y = percent)) +
  #geom_point(pch=21, colour = "black", alpha = 0.8, size = 2) +
  geom_quasirandom(pch = 21, varwidth = TRUE, width = 0.3, size = 1.5, alpha = 0.5, aes (fill = Study))+
  geom_boxplot(alpha = 0.3, width = 0.5, outlier.size = -1, lwd = 0.5, aes(fill = Study)) +
  #geom_line(alpha = 0.2, size = 0.5, aes(group = interaction(sample_ID, Tetramer), color = cell_type)) + 
  #stat_summary_bin(breaks = c(-1, 1, 4.5, 6.5, 8.5, 11.5, 20), fun=mean, geom = "line", size = 1, aes(group = cell_type, color = cell_type)) +
  scale_y_log10() +
  #stat_pvalue_manual(stat.test_all_parameters, hide.ns = TRUE, label = "p.adj.signif", remove.bracket = FALSE) +
  stat_pvalue_manual(stat.test_all_parameters_Study, hide.ns = TRUE, label = "p.adj.signif", remove.bracket = FALSE) +
  theme_bw() + theme(legend.position = "bottom") +  
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) + 
  labs(y = "Fraction") +
  labs(x= "") +
  labs(fill = "Data") +
  guides(color = "none") +
  theme(legend.position = "none") +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5)) + 
  ggtitle("Immune cell populations by Study") +
  theme(plot.title = element_text(hjust = 0.5,size = 20, face = "bold")) +
  scale_fill_manual(values = c("#CA3433", "#54BEEC")) +
  scale_color_manual(values = c("#CA3433", "#54BEEC"))+
  #scale_size_manual(values = c(2,5)) +
  #scale_alpha_manual(values = c(0.5, 1)) +
  facet_wrap(~parameter, ncol = 9) +
  theme(strip.background = element_blank(), strip.text.y = element_blank())
all_parameters_Study

layout2 <- "
AABBCC
AABBCC
DDDDDD
DDDDDD
DDDDDD
DDDDDD
DDDDDD
DDDDDD
DDDDDD
DDDDDD
"



IH_report_CyTOF <- UMAP_Frequencies_Study + UMAP_Frequencies_IH_status + UMAP_Frequencies_Disease + all_parameters_Study + 
  plot_layout(design = layout2)
IH_report_CyTOF


filename <- paste0("IH_report_CyTOF_", report_sample, ".pdf")
filename

ggsave(
  filename,
  plot = IH_report_CyTOF,
  device = NULL,
  path = report_directory,
  scale = 3,
  width = 5,
  height = 6,
  dpi = 300,
  limitsize = TRUE,)