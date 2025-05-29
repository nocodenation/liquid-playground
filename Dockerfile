FROM apache/nifi:2.4.0

USER root:root
RUN apt-get --allow-releaseinfo-change update
RUN apt-get install -y python3 python3-pip
USER nifi:nifi
