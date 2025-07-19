# Time MCP Server

A Model Context Protocol (MCP) server that provides time and timezone conversion capabilities.

## Features

### Available Tools

- `get_current_time` - Get current time in a specific timezone or system timezone
  - Required arguments:
    - `timezone` (string): IANA timezone name (e.g., 'America/New_York', 'Europe/London')

- `convert_time` - Convert time between timezones
  - Required arguments:
    - `source_timezone` (string): Source IANA timezone name
    - `time` (string): Time in 24-hour format (HH:MM)
    - `target_timezone` (string): Target IANA timezone name

## Configuration

The server is configured with the following environment variables:

- `PORT`: Server port (default: 3000)
- `NODE_ENV`: Environment mode (production)
- `MCP_SERVER_NAME`: Server identifier (time)
- `LOCAL_TIMEZONE`: Default timezone (America/New_York)

## Example Usage

### Get Current Time
```json
{
  "name": "get_current_time",
  "arguments": {
    "timezone": "Europe/Warsaw"
  }
}
```

Response:
```json
{
  "timezone": "Europe/Warsaw",
  "datetime": "2024-01-01T13:00:00+01:00",
  "is_dst": false
}
```

### Convert Time Between Timezones
```json
{
  "name": "convert_time",
  "arguments": {
    "source_timezone": "America/New_York",
    "time": "16:30",
    "target_timezone": "Asia/Tokyo"
  }
}
```

Response:
```json
{
  "source": {
    "timezone": "America/New_York",
    "datetime": "2024-01-01T12:30:00-05:00",
    "is_dst": false
  },
  "target": {
    "timezone": "Asia/Tokyo",
    "datetime": "2024-01-01T12:30:00+09:00",
    "is_dst": false
  },
  "time_difference": "+13.0h"
}
```

## Deployment

This server is deployed as part of the MCP servers cluster using Kubernetes manifests:

- `deployment.yaml`: Kubernetes deployment configuration
- `service.yaml`: Kubernetes service configuration
- `kustomization.yaml`: Kustomize configuration

The server runs using the `mcp/time:latest` Docker image and is accessible within the cluster at `time-mcp-server.mcp-servers.svc.cluster.local:3000`.

## Resource Requirements

- Memory: 64Mi (request) / 256Mi (limit)
- CPU: 50m (request) / 200m (limit)

## Example Questions

1. "What time is it now?" (will use system timezone)
2. "What time is it in Tokyo?"
3. "When it's 4 PM in New York, what time is it in London?"
4. "Convert 9:30 AM Tokyo time to New York time"
