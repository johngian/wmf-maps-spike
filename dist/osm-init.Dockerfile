FROM golang:1.11-buster

ARG PG_MAJOR="11"
ARG IMPOSM_REPO="https://github.com/omniscale/imposm3.git"
ARG IMPOSM_VERSION="v0.8.1"

RUN apt-get update && \
    # install newer packages from backports
    apt-get install -y --no-install-recommends \
    libgeos-dev \
    libleveldb-dev \
    libprotobuf-dev \
    osmctools \
    postgis \
    osmosis \
    wait-for-it && \
    # install postgresql client
    apt-get install -y --no-install-recommends \
    postgresql-client-$PG_MAJOR  && \
    ln -s /usr/lib/libgeos_c.so /usr/lib/libgeos.so && \
    rm -rf /var/lib/apt/lists/*

# add  github.com/omniscale/imposm3
RUN mkdir -p $GOPATH/src/github.com/omniscale/imposm3 \
 && cd  $GOPATH/src/github.com/omniscale/imposm3 \
 && go get github.com/tools/godep \
 # update to current omniscale/imposm3
 && git clone --quiet --depth 1 $IMPOSM_REPO -b $IMPOSM_VERSION \
        $GOPATH/src/github.com/omniscale/imposm3 \
 && make build \
 && ( [ -f imposm ] && mv imposm /usr/bin/imposm || mv imposm3 /usr/bin/imposm ) \
 # clean
 && rm -rf $GOPATH/bin/godep \
 && rm -rf $GOPATH/src/ \
 && rm -rf $GOPATH/pkg/

COPY ./scripts/osm-initial-import.sh /usr/bin/osm-initial-import

RUN chmod +x /usr/bin/osm-initial-import
