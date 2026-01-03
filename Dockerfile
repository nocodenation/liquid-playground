FROM apache/nifi:2.6.0

USER root:root
RUN apt-get --allow-releaseinfo-change update
RUN apt-get install -y python3 python3-pip

# POST_INSTALL_COMMANDS

# Copy custom NiFi NAR files from files directory if they exist
COPY --chown=nifi:nifi files/*.nar /opt/nifi/nifi-current/lib/

# Copy application files with correct ownership
COPY --chown=nifi:nifi files /files

USER nifi:nifi
