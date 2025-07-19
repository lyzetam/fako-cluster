#!/usr/bin/env node

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError,
} = require('@modelcontextprotocol/sdk/types.js');
const fs = require('fs-extra');
const path = require('path');
const mime = require('mime-types');

// Security configuration
const ALLOWED_DIRECTORIES = process.env.ALLOWED_DIRECTORIES?.split(',') || ['/projects'];
const MAX_FILE_SIZE = parseInt(process.env.MAX_FILE_SIZE || '10485760'); // 10MB default

class FilesystemMCPServer {
  private server: Server;

  constructor() {
    this.server = new Server(
      {
        name: 'filesystem-mcp-server',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupToolHandlers();
    this.setupErrorHandling();
  }

  private isPathAllowed(filePath: string): boolean {
    const resolvedPath = path.resolve(filePath);
    return ALLOWED_DIRECTORIES.some(allowedDir => {
      const resolvedAllowedDir = path.resolve(allowedDir);
      return resolvedPath.startsWith(resolvedAllowedDir);
    });
  }

  private setupToolHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: 'read_file',
            description: 'Read the contents of a file',
            inputSchema: {
              type: 'object',
              properties: {
                path: {
                  type: 'string',
                  description: 'Path to the file to read',
                },
              },
              required: ['path'],
            },
          },
          {
            name: 'write_file',
            description: 'Write content to a file',
            inputSchema: {
              type: 'object',
              properties: {
                path: {
                  type: 'string',
                  description: 'Path to the file to write',
                },
                content: {
                  type: 'string',
                  description: 'Content to write to the file',
                },
              },
              required: ['path', 'content'],
            },
          },
          {
            name: 'list_directory',
            description: 'List contents of a directory',
            inputSchema: {
              type: 'object',
              properties: {
                path: {
                  type: 'string',
                  description: 'Path to the directory to list',
                },
              },
              required: ['path'],
            },
          },
          {
            name: 'create_directory',
            description: 'Create a directory',
            inputSchema: {
              type: 'object',
              properties: {
                path: {
                  type: 'string',
                  description: 'Path to the directory to create',
                },
              },
              required: ['path'],
            },
          },
          {
            name: 'delete_file',
            description: 'Delete a file',
            inputSchema: {
              type: 'object',
              properties: {
                path: {
                  type: 'string',
                  description: 'Path to the file to delete',
                },
              },
              required: ['path'],
            },
          },
          {
            name: 'file_info',
            description: 'Get information about a file or directory',
            inputSchema: {
              type: 'object',
              properties: {
                path: {
                  type: 'string',
                  description: 'Path to the file or directory',
                },
              },
              required: ['path'],
            },
          },
        ],
      };
    });

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'read_file':
            return await this.readFile(args.path as string);
          case 'write_file':
            return await this.writeFile(args.path as string, args.content as string);
          case 'list_directory':
            return await this.listDirectory(args.path as string);
          case 'create_directory':
            return await this.createDirectory(args.path as string);
          case 'delete_file':
            return await this.deleteFile(args.path as string);
          case 'file_info':
            return await this.getFileInfo(args.path as string);
          default:
            throw new McpError(
              ErrorCode.MethodNotFound,
              `Unknown tool: ${name}`
            );
        }
      } catch (error) {
        if (error instanceof McpError) {
          throw error;
        }
        throw new McpError(
          ErrorCode.InternalError,
          `Error executing tool ${name}: ${error instanceof Error ? error.message : String(error)}`
        );
      }
    });
  }

  private async readFile(filePath: string) {
    if (!this.isPathAllowed(filePath)) {
      throw new McpError(ErrorCode.InvalidRequest, `Access denied to path: ${filePath}`);
    }

    try {
      const stats = await fs.stat(filePath);
      if (stats.size > MAX_FILE_SIZE) {
        throw new McpError(ErrorCode.InvalidRequest, `File too large: ${stats.size} bytes`);
      }

      const content = await fs.readFile(filePath, 'utf8');
      const mimeType = mime.lookup(filePath) || 'text/plain';

      return {
        content: [
          {
            type: 'text',
            text: `File: ${filePath}\nMIME Type: ${mimeType}\nSize: ${stats.size} bytes\n\n${content}`,
          },
        ],
      };
    } catch (error) {
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to read file: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  private async writeFile(filePath: string, content: string) {
    if (!this.isPathAllowed(filePath)) {
      throw new McpError(ErrorCode.InvalidRequest, `Access denied to path: ${filePath}`);
    }

    try {
      await fs.ensureDir(path.dirname(filePath));
      await fs.writeFile(filePath, content, 'utf8');

      return {
        content: [
          {
            type: 'text',
            text: `Successfully wrote ${content.length} characters to ${filePath}`,
          },
        ],
      };
    } catch (error) {
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to write file: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  private async listDirectory(dirPath: string) {
    if (!this.isPathAllowed(dirPath)) {
      throw new McpError(ErrorCode.InvalidRequest, `Access denied to path: ${dirPath}`);
    }

    try {
      const items = await fs.readdir(dirPath);
      const itemDetails = await Promise.all(
        items.map(async (item) => {
          const itemPath = path.join(dirPath, item);
          const stats = await fs.stat(itemPath);
          return {
            name: item,
            type: stats.isDirectory() ? 'directory' : 'file',
            size: stats.size,
            modified: stats.mtime.toISOString(),
          };
        })
      );

      return {
        content: [
          {
            type: 'text',
            text: `Directory listing for ${dirPath}:\n\n${itemDetails
              .map(
                (item) =>
                  `${item.type === 'directory' ? '📁' : '📄'} ${item.name} (${
                    item.type === 'directory' ? 'dir' : `${item.size} bytes`
                  }) - Modified: ${item.modified}`
              )
              .join('\n')}`,
          },
        ],
      };
    } catch (error) {
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to list directory: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  private async createDirectory(dirPath: string) {
    if (!this.isPathAllowed(dirPath)) {
      throw new McpError(ErrorCode.InvalidRequest, `Access denied to path: ${dirPath}`);
    }

    try {
      await fs.ensureDir(dirPath);

      return {
        content: [
          {
            type: 'text',
            text: `Successfully created directory: ${dirPath}`,
          },
        ],
      };
    } catch (error) {
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to create directory: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  private async deleteFile(filePath: string) {
    if (!this.isPathAllowed(filePath)) {
      throw new McpError(ErrorCode.InvalidRequest, `Access denied to path: ${filePath}`);
    }

    try {
      await fs.remove(filePath);

      return {
        content: [
          {
            type: 'text',
            text: `Successfully deleted: ${filePath}`,
          },
        ],
      };
    } catch (error) {
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to delete file: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  private async getFileInfo(filePath: string) {
    if (!this.isPathAllowed(filePath)) {
      throw new McpError(ErrorCode.InvalidRequest, `Access denied to path: ${filePath}`);
    }

    try {
      const stats = await fs.stat(filePath);
      const mimeType = mime.lookup(filePath) || 'unknown';

      return {
        content: [
          {
            type: 'text',
            text: `File Information for ${filePath}:
Type: ${stats.isDirectory() ? 'Directory' : 'File'}
Size: ${stats.size} bytes
MIME Type: ${mimeType}
Created: ${stats.birthtime.toISOString()}
Modified: ${stats.mtime.toISOString()}
Accessed: ${stats.atime.toISOString()}
Permissions: ${stats.mode.toString(8)}`,
          },
        ],
      };
    } catch (error) {
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to get file info: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  private setupErrorHandling() {
    this.server.onerror = (error) => {
      console.error('[MCP Error]', error);
    };

    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Filesystem MCP server running on stdio');
  }
}

const server = new FilesystemMCPServer();
server.run().catch(console.error);
