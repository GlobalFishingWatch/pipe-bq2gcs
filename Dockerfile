FROM python:3.7-buster

# Configure the working directory
RUN mkdir -p /opt/project
WORKDIR /opt/project

# Download and install google cloud. See the dockerfile at
# https://hub.docker.com/r/google/cloud-sdk/~/dockerfile/
ENV CLOUD_SDK_VERSION=292.0.0
ENV PATH "$PATH:/opt/google-cloud-sdk/bin/"
ENV GOLANG_VERSION="go1.14.linux-amd64"
RUN apt-get -qqy update && apt-get install -qqy \
        curl \
        gcc \
        python3-dev \
        python3-pip \
        apt-transport-https \
        lsb-release \
        openssh-client \
        git \
        make \
        gnupg && \
    pip install -U crcmod && \
    echo 'deb http://deb.debian.org/debian/ sid main' >> /etc/apt/sources.list && \
    export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
    echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get update && \
    apt-get install -y google-cloud-sdk=${CLOUD_SDK_VERSION}-0 \
       && gcloud --version

#GoLang
RUN wget -q https://dl.google.com/go/${GOLANG_VERSION}.tar.gz && \
    tar -C /usr/local -xzf ${GOLANG_VERSION}.tar.gz && \
    rm -f ${GOLANG_VERSION}.tar.gz
ENV PATH /usr/local/go/bin:$PATH
ENV GOPATH /usr/local/go/workspace
ENV PATH /usr/local/go/workspace/bin:$PATH

# Setup a volume for configuration and auth data
VOLUME ["/root/.config"]

# Setup local application dependencies
COPY . /opt/project

# install
# Required to build the Docker Image
RUN pip install -r requirements.txt
RUN pip install -e .

# Setup the entrypoint for quickly executing the pipelines
ENTRYPOINT ["scripts/run.go"]
