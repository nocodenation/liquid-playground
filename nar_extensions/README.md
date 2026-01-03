# Custom NAR Extensions

This directory contains custom Apache NiFi NAR (NiFi Archive) files that extend NiFi functionality.

## Installed NARs

- `nodejs-app-gateway-service-api-nar-1.0.0-SNAPSHOT.nar` - API interfaces for NodeJS App Gateway
- `nodejs-app-gateway-service-nar-1.0.0-SNAPSHOT.nar` - Gateway service implementation (includes CORS support)
- `nodejs-app-gateway-processors-nar-1.0.0-SNAPSHOT.nar` - Processors for receiving requests from NodeJS apps

## Installation Process

NARs in this directory are **automatically copied** to NiFi's lib directory on container startup via volume mount.

### Manual Installation (if needed)

If you need to manually install or update NARs:

```bash
# 1. Copy NARs from nar_extensions to lib directory
docker exec liquid-playground bash -c "cp /opt/nifi/nifi-current/nar_extensions/*.nar /opt/nifi/nifi-current/lib/"

# 2. Delete cached unpacked NARs (important!)
docker exec liquid-playground bash -c "rm -rf /opt/nifi/nifi-current/work/nar/extensions/nodejs-app-gateway-*"

# 3. Restart NiFi to load new NARs
docker exec liquid-playground /opt/nifi/nifi-current/bin/nifi.sh restart
```

### Verifying Installation

After NiFi restarts, check the logs to confirm the NARs were loaded:

```bash
docker exec liquid-playground grep "nodejs-app-gateway" /opt/nifi/nifi-current/logs/nifi-app.log | grep "Loaded NAR"
```

You should see the NARs loaded from `/opt/nifi/nifi-current/lib/` (not from work/nar/extensions).

## Important Notes

- **Cache Clearing**: NiFi caches unpacked NARs in `work/nar/extensions/`. When updating NARs, you MUST delete the old cached versions, otherwise NiFi will continue using the old code.
- **Container Restarts**: NARs in this directory survive container restarts via the volume mount defined in docker-compose.yml
- **CORS Support**: The gateway service NAR includes CORS headers for browser-based clients

## Related Configuration

The NARs are mounted via docker-compose.yml:

```yaml
volumes:
  - ./nar_extensions:/opt/nifi/nifi-current/nar_extensions:z
```

## Development Workflow

When rebuilding NARs during development:

1. Build new NARs in the source project
2. Copy updated NARs to this directory
3. Follow the Manual Installation steps above
4. In NiFi UI, re-enable affected controller services and restart processors