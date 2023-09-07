FROM rocker/r-ver:4.0.0

WORKDIR /service

RUN apt-get update
# install dependencies
RUN apt-get -y install wget && apt-get -y install gnupg && apt-get -y install curl
# R program dependencies
RUN apt-get install -y libudunits2-dev libgdal-dev libgeos-dev libproj-dev && apt-get -y install libnlopt-dev && apt-get -y install pkg-config && apt-get -y install gdal-bin && apt-get install -y libgdal-dev




# install Go
RUN wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz

RUN  rm -rf /usr/local/go && tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz

ENV PATH="${PATH}:/usr/local/go/bin"

# cleanup
RUN rm -f go1.21.0.linux-amd64.tar.gz

COPY . ./

RUN go build -o /service/main main.go

RUN Rscript -e "install.packages(c('ggplot2', 'readxl', 'dplyr', 'RColorBrewer', 'viridis', 'cowplot', 'patchwork', 'tidyr', 'stringr', 'ggsci', 'magrittr', 'mblm', 'rstatix', 'psych', 'ggbeeswarm', 'umap', 'reshape2', 'pheatmap', 'plotly', 'spdep'), Ncpus = 10)"
RUN Rscript -e "install.packages(c('ggpubr'), repos = 'https://cloud.r-project.org/', dependencies = TRUE)"

#install nextflow dependencies
RUN wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | apt-key add -
RUN echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list
RUN apt-get update
RUN apt-get -y install temurin-17-jdk


# install nextflow
RUN wget -qO- https://get.nextflow.io | bash && chmod +x nextflow && cp ./nextflow /usr/local
RUN apt-get -y install graphviz

ENV PATH="${PATH}:/usr/local/"

# cleanup
RUN rm -f /service/nextflow

# set desired nextflow version
# RUN export NXF_VER=23.04.1

ENTRYPOINT [ "/service/main" ]