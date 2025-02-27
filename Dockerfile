## Build Docker image for measurement and reporting of the dhcp pipelines 
## within a Docker container
##
## How to build the image:
## - Make an image for the structural pipline (see project README) 
## - Change to top-level directory of structural-pipeline-measures source tree
## - Run "docker build -t <user>/structural-pipeline-measures:latest ."
##
## Upload image to Docker Hub:
## - Log in with "docker login" if necessary
## - Push image using "docker push <user>/structural-pipeline:latest"
##

FROM gerardmartijuan/dhcp-pipeline-multifact:latest
MAINTAINER John Cupitt <jcupitt@gmail.com>
LABEL Description="dHCP structural-pipeline measure and report" Vendor="BioMedIA"

# Git repository and commit SHA from which this Docker image was built
# (see https://microbadger.com/#/labels)
ARG VCS_REF
LABEL org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/jcupitt/structural-pipeline-measures"

# Update package lists and install necessary tools
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    zlib1g-dev \
    libssl-dev \
    libffi-dev \
    libsqlite3-dev \
    libreadline-dev \
    libbz2-dev

# Download and compile Python 3.9 (adjust the version as needed)
RUN wget https://www.python.org/ftp/python/3.8.10/Python-3.8.10.tgz && \
    tar xvf Python-3.8.10.tgz && \
    cd Python-3.8.10 && \
    ./configure --enable-optimizations && \
    make -j$(nproc) && \
    make install

# Cleanup
RUN rm -rf /Python-3.8.10* && \
    apt-get purge -y build-essential wget && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set Python 3.9 as the default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.8 1

RUN apt-get update && apt-get install -y wget

# Install pip for Python 3.8
RUN wget https://bootstrap.pypa.io/get-pip.py && \
    python3 get-pip.py && \
    rm get-pip.py

# RUN apt-get install -y \
#	python3-pip
RUN pip3 install --upgrade pip

# these packages are listed in packages/*/requirement.txt
# install them now to speed up structural-pipeline-measure install later
#
# nipype insists on prov 1.5.0
# 
# pandas-0.23.0 breaks with py-3.5.2 ... stick with 0.22.0 for now
RUN pip3 install --upgrade \
	h5py \
	mock \
	numpy \
	six \
	pandas \
	nitime \
	dipy \
	lockfile \
	jinja2 \
	seaborn \
	pyPdf2 \
	PyYAML \
	future \
	simplejson \
	prov \
	smartypants \
	rson \
	tenjin \
	aafigure \
	nipype \
	alabaster \
	Babel \
	coverage \
	docutils \
	MarkupSafe \
	nose \
	pdfrw \
	Pillow \
	Pygments \
	pytz \
	reportlab \
	snowballstemmer \
	Sphinx \
	sphinx-rtd-theme 

COPY . /usr/src/structural-pipeline-measures

RUN cd /usr/src/structural-pipeline-measures \
    && pip3 install packages/structural_dhcp_svg2rlg-0.3/ \
    && pip3 install packages/structural_dhcp_rst2pdf-aquavitae/ \
    && pip3 install packages/structural_dhcp_mriqc/ 

ENV MPLCONFIGDIR /tmp/matplotlib_config

WORKDIR /data 
ENTRYPOINT ["/usr/src/structural-pipeline-measures/pipeline.sh"]
CMD ["-help"]

