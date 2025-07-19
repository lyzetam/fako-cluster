# Filesystem MCP Server

A Model Context Protocol (MCP) server that provides secure filesystem operations for reading, writing, and managing files within containerized environments.

## Features

- **Secure File Operations**: Read, write, create, and delete files with path validation
- **Directory Management**: List directory contents and create new directories
- **File Information**: Get detailed metadata about files and directories
- **Security Controls**: Configurable allowed directories and file size limits
- **Container Ready**: Designed to run in Docker containers with proper security contexts

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

### Environment Variables

- `ALLOWED_DIRECTORIES`: Comma-separated list of allowed directory paths (default: `/projects`)
- `MAX_FILE_SIZE`: Maximum file size in bytes for read operations (default: `10485760` - 10MB)

### Security Features

- **Path Validation**: All file operations are restricted to configured allowed directories
- **File Size Limits**: Prevents reading of excessively large files
- **Non-root Execution**: Runs as non-root user (UID 1000) in containers
- **Read-only Mounts**: Supports read-only volume mounts for additional security

## Docker Usage

### Building the Image

```bash
docker build -t mcp/filesystem -f src/filesystem/Dockerfile .
```

### Running the Container

```bash
docker run -i --rm \
  --mount type=bind,src=/path/to/data,dst=/projects/data \
  --mount type=bind,src=/path/to/logs,dst=/projects/logs,ro \
  mcp/filesystem \
  /projects
```

### Environment Configuration

```bash
docker run -i --rm \
  -e ALLOWED_DIRECTORIES="/projects/data,/projects/logs" \
  -e MAX_FILE_SIZE="5242880" \
  --mount type=bind,src=/path/to/data,dst=/projects/data \
  mcp/filesystem \
  /projects
```

## Kubernetes Deployment

The server is designed to run in Kubernetes with:

- **Persistent Volumes**: For data, logs, and configuration storage
- **Security Context**: Non-root execution with proper user/group settings
- **Resource Limits**: Configurable CPU and memory limits
- **Service Discovery**: ClusterIP service for internal access

### Example MCP Client Configuration

```json
{
  "mcp": {
    "servers": {
      "filesystem": {
        "command": "docker",
        "args": [
          "run",
          "-i",
          "--rm",
          "--mount", "type=bind,src=${workspaceFolder},dst=/projects/workspace",
          "mcp/filesystem",
          "/projects"
        ]
      }
    }
  }
}
```

## Development

### Local Development

```bash
cd src/filesystem
npm install
npm run dev
```

### Building

```bash
npm run build
npm start
```

## Security Considerations

1. **Path Traversal Protection**: All paths are resolved and validated against allowed directories
2. **File Size Limits**: Prevents memory exhaustion from large file reads
3. **Container Security**: Runs as non-root user with minimal privileges
4. **Volume Mounts**: Use read-only mounts where appropriate
5. **Network Isolation**: No network access required for basic file operations

## License

This MCP server is part of the fako-cluster project.
