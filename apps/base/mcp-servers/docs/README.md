# Filesystem MCP Server

A Model Context Protocol (MCP) server that provides secure filesystem operations for reading, writing, and managing files within Kubernetes environments.

## Overview

This MCP server is designed to run in Kubernetes with an init container pattern that builds the application from source code stored in a ConfigMap. This approach ensures that all source code is contained within the namespace and follows GitOps principles.

## Architecture

### Container Image Build Pattern

The deployment uses a separate Job to build the Docker image:
1. **Image Builder Job**: Builds a Docker image from source code stored in ConfigMap
2. **Main Deployment**: Uses the locally built Docker image
3. **Clean Separation**: Build process is separate from runtime deployment

### Security Features

- **Path Validation**: All file operations are restricted to configured allowed directories
- **File Size Limits**: Prevents reading of excessively large files (default: 10MB)
- **Non-root Execution**: Runs as non-root user (UID 1000) in containers
- **Namespace Isolation**: All resources are contained within the mcp-servers namespace

## Available Tools

### `read_file`
Read the contents of a file.
- **Parameters**: `path` (string) - Path to the file to read
- **Security**: Validates path is within allowed directories and file size limits

### `write_file`
Write content to a file.
- **Parameters**: 
  - `path` (string) - Path to the file to write
  - `content` (string) - Content to write to the file
- **Security**: Validates path is within allowed directories

### `list_directory`
List contents of a directory.
- **Parameters**: `path` (string) - Path to the directory to list
- **Returns**: File and directory listings with metadata

### `create_directory`
Create a directory (including parent directories if needed).
- **Parameters**: `path` (string) - Path to the directory to create

### `delete_file`
Delete a file or directory.
- **Parameters**: `path` (string) - Path to the file or directory to delete

### `file_info`
Get detailed information about a file or directory.
- **Parameters**: `path` (string) - Path to the file or directory
- **Returns**: Size, type, timestamps, permissions, and MIME type

## Configuration

### Command Line Arguments (Preferred)
The server accepts allowed directories as command line arguments:
```bash
node index.js /data /logs /config
```

### Environment Variables (Fallback)
- `ALLOWED_DIRECTORIES`: Comma-separated list of allowed directory paths (default: `/projects`)
- `MAX_FILE_SIZE`: Maximum file size in bytes for read operations (default: `10485760` - 10MB)

## Kubernetes Resources

### ConfigMap (`configmap.yaml`)
Contains the complete source code for the MCP server:
- `package.json`: Node.js package configuration
- `index.js`: Main server implementation
- `Dockerfile`: Container build instructions (for reference)

### Image Builder Job (`image-builder-job.yaml`)
- **Docker-in-Docker**: Uses Docker daemon to build images from ConfigMap source
- **Source Mounting**: Mounts ConfigMap containing source files
- **Image Creation**: Builds `filesystem-mcp:latest` image locally

### Deployment (`deployment.yaml`)
- **Main Container**: Runs the locally built `filesystem-mcp:latest` image
- **Image Pull Policy**: `Never` to use locally built image
- **Volumes**: `shared-data`, `log-storage`, `config-storage` persistent volumes

### Service (`service.yaml`)
ClusterIP service for internal access (though MCP typically uses stdio transport).

### Storage (`storage.yaml`)
Three persistent volume claims:
- `filesystem-mcp-data`: Main data storage
- `filesystem-mcp-logs`: Log storage
- `filesystem-mcp-config`: Configuration storage

## Deployment

### Build and Deploy Process
1. **Apply Resources**: This creates the ConfigMap, Job, and Deployment
   ```bash
   kubectl apply -k apps/base/mcp-servers/filesystem-mcp/
   ```

2. **Monitor Image Build**: Watch the image builder job
   ```bash
   kubectl logs -n mcp-servers job/filesystem-mcp-image-builder -f
   ```

3. **Verify Image Build**: Check that the image was built successfully
   ```bash
   kubectl get jobs -n mcp-servers -l app.kubernetes.io/component=image-builder
   ```

4. **Deploy Main Application**: The deployment will use the locally built image
   ```bash
   kubectl get pods -n mcp-servers -l app.kubernetes.io/name=filesystem-mcp-server
   kubectl logs -n mcp-servers -l app.kubernetes.io/name=filesystem-mcp-server -f
   ```

## Development

### Updating Source Code
To update the MCP server code:

1. Edit the source code in the ConfigMap (`configmap.yaml`)
2. Apply the updated ConfigMap:
   ```bash
   kubectl apply -f apps/base/mcp-servers/filesystem-mcp/configmap.yaml
   ```
3. Restart the deployment to trigger a rebuild:
   ```bash
   kubectl rollout restart deployment/filesystem-mcp-server -n mcp-servers
   ```

### Local Testing
You can test the source code locally by extracting it from the ConfigMap:
```bash
kubectl get configmap filesystem-mcp-source -n mcp-servers -o jsonpath='{.data.index\.js}' > test-index.js
kubectl get configmap filesystem-mcp-source -n mcp-servers -o jsonpath='{.data.package\.json}' > test-package.json
npm install
node test-index.js /tmp
```

## MCP Client Configuration

### Example Configuration
```json
{
  "mcp": {
    "servers": {
      "filesystem": {
        "command": "kubectl",
        "args": [
          "exec",
          "-n", "mcp-servers",
          "deployment/filesystem-mcp-server",
          "-c", "filesystem-mcp-server",
          "--",
          "node", "/app/index.js",
          "/data", "/logs", "/config"
        ]
      }
    }
  }
}
```

## Monitoring

### Health Checks
The server logs to stderr, which can be monitored via Kubernetes logs:
```bash
kubectl logs -n mcp-servers -l app.kubernetes.io/name=filesystem-mcp-server -f
```

### Resource Usage
Monitor resource consumption:
```bash
kubectl top pods -n mcp-servers -l app.kubernetes.io/name=filesystem-mcp-server
```

## Security Considerations

1. **Path Traversal Protection**: All paths are resolved and validated against allowed directories
2. **File Size Limits**: Prevents memory exhaustion from large file reads
3. **Container Security**: Runs as non-root user with minimal privileges
4. **Volume Mounts**: Use appropriate mount options (ro for read-only access)
5. **Network Isolation**: No network access required for basic file operations
6. **Namespace Isolation**: All resources are contained within the mcp-servers namespace

## Troubleshooting

### Common Issues

1. **Init Container Fails**: Check init container logs for build errors
2. **Permission Denied**: Verify securityContext and volume permissions
3. **Path Access Denied**: Ensure requested paths are within allowed directories
4. **File Too Large**: Check MAX_FILE_SIZE environment variable

### Debug Commands
```bash
# Check init container logs
kubectl logs -n mcp-servers deployment/filesystem-mcp-server -c build-mcp-server

# Check main container logs
kubectl logs -n mcp-servers deployment/filesystem-mcp-server -c filesystem-mcp-server

# Exec into container for debugging
kubectl exec -n mcp-servers deployment/filesystem-mcp-server -c filesystem-mcp-server -it -- /bin/sh

# Check volume mounts
kubectl describe pod -n mcp-servers -l app.kubernetes.io/name=filesystem-mcp-server
```

## License

This MCP server is part of the fako-cluster project.

# Fetch MCP Server

A Model Context Protocol server that provides web content fetching capabilities. This server enables LLMs to retrieve and process content from web pages, converting HTML to markdown for easier consumption.

## Features

- **Web Content Fetching**: Retrieve content from any publicly accessible URL
- **HTML to Markdown Conversion**: Automatically converts HTML content to clean markdown format
- **Security Restrictions**: Respects robots.txt files and implements rate limiting
- **Chunked Reading**: Support for reading large pages in chunks using start_index parameter
- **Raw Content Option**: Option to retrieve raw HTML content without markdown conversion

## Available Tools

- `fetch` - Fetches a URL from the internet and extracts its contents as markdown
  - `url` (string, required): URL to fetch
  - `max_length` (integer, optional): Maximum number of characters to return (default: 5000)
  - `start_index` (integer, optional): Start content from this character index (default: 0)
  - `raw` (boolean, optional): Get raw content without markdown conversion (default: false)

## Security Features

- **Network Policies**: Restricts network access to HTTP/HTTPS and DNS only
- **Pod Security Policies**: Runs as non-root user with dropped capabilities
- **Rate Limiting**: Built-in rate limiting to prevent abuse
- **Robots.txt Compliance**: Respects website robots.txt files by default
- **Resource Limits**: CPU and memory limits to prevent resource exhaustion

## Configuration

The server is configured through environment variables:

- `FETCH_MAX_LENGTH`: Maximum content length (default: 5000)
- `FETCH_TIMEOUT`: Request timeout in milliseconds (default: 30000)
- `FETCH_USER_AGENT`: Custom user agent string
- `FETCH_RESPECT_ROBOTS`: Whether to respect robots.txt (default: true)
- `FETCH_RATE_LIMIT`: Maximum requests per window (default: 10)
- `FETCH_RATE_WINDOW`: Rate limiting window in milliseconds (default: 60000)

## Security Considerations

⚠️ **CAUTION**: This server can access external web content and may represent a security risk if not properly configured. The server includes several security measures:

1. Network policies restrict egress to HTTP/HTTPS and DNS only
2. Pod security policies enforce non-root execution
3. Rate limiting prevents abuse
4. Robots.txt compliance is enabled by default
5. Resource limits prevent resource exhaustion

## Usage Example

```json
{
  "tool": "fetch",
  "arguments": {
    "url": "https://example.com/article",
    "max_length": 10000,
    "start_index": 0,
    "raw": false
  }
}
```

## Deployment

This server is deployed as part of the MCP servers namespace and includes:

- Deployment with security hardening
- ClusterIP service for internal access
- Persistent volume for caching
- Network policies for traffic control
- Pod security policies for runtime security

The server uses the official `mcp-server-fetch` Python package installed via `uv` in a secure container environment.

