FROM apache/nifi:2.6.0

USER root:root
RUN apt-get --allow-releaseinfo-change update
RUN apt-get install -y python3 python3-pip

# Startup script to handle flow persistence
RUN echo '#!/bin/bash\n\
\n\
# Define persistence paths\n\
PERSISTENT_DIR="/opt/nifi/nifi-current/conf_persistent"\n\
CONF_DIR="/opt/nifi/nifi-current/conf"\n\
FLOW_FILE="flow.json.gz"\n\
\n\
# 1. Restore on Startup\n\
if [ -f "$PERSISTENT_DIR/$FLOW_FILE" ]; then\n\
    echo "Restoring persisted flow configuration..."\n\
    cp "$PERSISTENT_DIR/$FLOW_FILE" "$CONF_DIR/$FLOW_FILE"\n\
    # Also restore users/authorizations if they exist (for multi-tenant/secure setups)\n\
    [ -f "$PERSISTENT_DIR/users.xml" ] && cp "$PERSISTENT_DIR/users.xml" "$CONF_DIR/users.xml"\n\
    [ -f "$PERSISTENT_DIR/authorizations.xml" ] && cp "$PERSISTENT_DIR/authorizations.xml" "$CONF_DIR/authorizations.xml"\n\
else\n\
    echo "No persisted flow found. Starting fresh."\n\
fi\n\
\n\
# 2. Background Backup Loop\n\
(while true; do\n\
    sleep 15\n\
    if [ -f "$CONF_DIR/$FLOW_FILE" ]; then\n\
        # Simple copy, ignore errors\n\
        cp "$CONF_DIR/$FLOW_FILE" "$PERSISTENT_DIR/$FLOW_FILE" 2>/dev/null\n\
        [ -f "$CONF_DIR/users.xml" ] && cp "$CONF_DIR/users.xml" "$PERSISTENT_DIR/users.xml" 2>/dev/null\n\
        [ -f "$CONF_DIR/authorizations.xml" ] && cp "$CONF_DIR/authorizations.xml" "$PERSISTENT_DIR/authorizations.xml" 2>/dev/null\n\
    fi\n\
done) &\n\
\n\
# 3. Start NiFi (Pass control to original script)\n\
exec ../scripts/start.sh\n\
' > /opt/nifi/nifi-current/start_and_persist.sh && chmod +x /opt/nifi/nifi-current/start_and_persist.sh

USER nifi:nifi
ENTRYPOINT ["/opt/nifi/nifi-current/start_and_persist.sh"]
