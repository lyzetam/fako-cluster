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
