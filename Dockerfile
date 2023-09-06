FROM rocker/r-ver

WORKDIR /service

RUN apt-get update
# install dependencies
RUN apt-get -y install wget && apt-get -y install gnupg && apt-get -y install curl
# R program dependencies
RUN apt-get install -y  libudunits2-dev libgdal-dev libgeos-dev libproj-dev && apt-get -y install libnlopt-dev && apt-get -y install pkg-config && apt-get -y install gdal-bin && apt-get install -y libgdal-dev

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

# install aws-lambda-rie
RUN curl -Lo aws-lambda-rie https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie \
&& chmod +x aws-lambda-rie && mv aws-lambda-rie /usr/local/bin/aws-lambda-rie

ENTRYPOINT [ "/service/entry_script.sh" ]