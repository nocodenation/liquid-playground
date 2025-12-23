FROM apache/nifi:2.6.0

USER root:root
RUN apt-get --allow-releaseinfo-change update
RUN apt-get install -y python3 python3-pip

# POST_INSTALL_COMMANDS

USER nifi:nifi
