FROM rocker/r-ver

RUN apt-get -y update && apt-get install -y  libudunits2-dev libgdal-dev libgeos-dev libproj-dev && apt-get -y install libnlopt-dev && apt-get -y install pkg-config && apt-get -y install gdal-bin && apt-get install -y libgdal-dev

WORKDIR /tmp

COPY . ./

RUN Rscript -e "install.packages(c('ggplot2', 'readxl', 'dplyr', 'RColorBrewer', 'viridis', 'cowplot', 'patchwork', 'tidyr', 'stringr', 'ggsci', 'magrittr', 'mblm', 'rstatix', 'psych', 'ggbeeswarm', 'umap', 'reshape2', 'pheatmap', 'plotly', 'spdep'), Ncpus = 6)"
RUN Rscript -e "install.packages(c('ggpubr'), repos = 'https://cloud.r-project.org/', dependencies = TRUE)"
ENTRYPOINT ["Rscript", "IH_Report_CyTOF_20230531.R"]