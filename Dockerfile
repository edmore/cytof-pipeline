FROM rocker/r-ver:4.2.1

WORKDIR /service

RUN apt clean && apt-get update
# install dependencies
RUN apt-get -y install wget && apt-get -y install gnupg && apt-get -y install curl
# RUN wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | apt-key add -
# RUN echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list
# RUN apt-get update
# # R program dependencies
# RUN apt-get install -y  libudunits2-dev libgdal-dev libgeos-dev libproj-dev && apt-get -y install libnlopt-dev && apt-get -y install pkg-config && apt-get -y install gdal-bin && apt-get install -y libgdal-dev
# # next flow dependencies
# RUN apt-get -y install temurin-17-jdk

# # install nextflow
# RUN wget -qO- https://get.nextflow.io | bash && chmod +x nextflow && cp ./nextflow /usr/local
# RUN apt-get -y install graphviz

# ENV PATH="${PATH}:/usr/local/"

# # cleanup
# RUN rm -f /service/nextflow

# set desired nextflow version
# RUN export NXF_VER=23.04.1

# install Go
RUN wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz

RUN  rm -rf /usr/local/go && tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz

ENV PATH="${PATH}:/usr/local/go/bin"

# cleanup
RUN rm -f go1.21.0.linux-amd64.tar.gz

COPY . ./

RUN go build -o /service/main main.go

# # install devtools
# RUN apt-get -y install libcurl4-openssl-dev libfontconfig1-dev libxml2-dev libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev
# RUN apt install -y build-essential libcurl4-gnutls-dev libxml2-dev libssl-dev libgit2-dev cmake libglpk-dev
# RUN Rscript -e "install.packages(c('BH'), repos = 'https://cloud.r-project.org/', dependencies = TRUE)"
# RUN Rscript -e "install.packages(c('devtools'), repos = 'https://cloud.r-project.org/', dependencies = TRUE)"

# # install BiocManager
# RUN R --version
# RUN Rscript -e "install.packages('BiocManager')"

# # install I3HQC package
# RUN Rscript -e "install.packages(c('ggplot2', 'readxl', 'dplyr', 'RColorBrewer', 'viridis', 'cowplot', 'patchwork', 'tidyr', 'stringr', 'ggsci', 'magrittr', 'mblm', 'rstatix', 'psych', 'ggbeeswarm', 'umap', 'reshape2', 'pheatmap', 'plotly', 'spdep'), Ncpus = 10)" # for Cytof Report
# RUN Rscript -e "install.packages(c('ggpubr'), repos = 'https://cloud.r-project.org/', dependencies = TRUE)"
# RUN Rscript -e "install.packages(c('nloptr', 'lme4', 'pbkrtest', 'car', 'lubridate', 'gt', 'gtsave', 'chromate'), Ncpus = 10)"
# RUN Rscript -e "BiocManager::install('RProtoBufLib')"
# RUN Rscript -e "BiocManager::install('cytolib')"
# RUN Rscript -e "BiocManager::install('flowCore')"
# RUN Rscript -e "BiocManager::install('FlowSOM')"
# RUN Rscript -e "install.packages(c('tidyverse'), Ncpus = 10)"
# RUN Rscript -e "require(devtools);library(devtools);devtools::install_github('ianmoran11/mmtable2');devtools::install_local('./I3HQC.zip')"

# install aws-lambda-rie
# RUN curl -Lo aws-lambda-rie https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie \
# && chmod +x aws-lambda-rie && mv aws-lambda-rie /usr/local/bin/aws-lambda-rie

RUN mkdir -p data

ENTRYPOINT [ "/service/main" ]