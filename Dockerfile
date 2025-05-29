FROM docker.env.liquidvu.com/liquid-nifi:master-2.2.0-latest-ci-python

USER root:root
RUN apt-get --allow-releaseinfo-change update
RUN apt-get install -y python3 python3-pip
USER nifi:nifi
