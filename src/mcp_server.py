"""
Sample MCP Server for Azure Web App Deployment

This is a simple MCP server that can be deployed to Azure Web App
and managed through Azure API Management (APIM).
"""

import asyncio
import json
import logging
import os
from typing import Any

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize MCP server
app = Server("azure-mcp-server")

# Define available tools
TOOLS = [
    Tool(
        name="echo",
        description="Echoes back the input message",
        inputSchema={
            "type": "object",
            "properties": {
                "message": {
                    "type": "string",
                    "description": "The message to echo back"
                }
            },
            "required": ["message"]
        }
    ),
    Tool(
        name="get_environment",
        description="Returns the current environment variables (filtered)",
        inputSchema={
            "type": "object",
            "properties": {
                "prefix": {
                    "type": "string",
                    "description": "Filter environment variables by prefix (optional)"
                }
            }
        }
    ),
    Tool(
        name="health_check",
        description="Performs a health check of the server",
        inputSchema={
            "type": "object",
            "properties": {}
        }
    ),
    Tool(
        name="calculate",
        description="Performs basic arithmetic calculations",
        inputSchema={
            "type": "object",
            "properties": {
                "operation": {
                    "type": "string",
                    "enum": ["add", "subtract", "multiply", "divide"],
                    "description": "The arithmetic operation to perform"
                },
                "a": {
                    "type": "number",
                    "description": "First operand"
                },
                "b": {
                    "type": "number",
                    "description": "Second operand"
                }
            },
            "required": ["operation", "a", "b"]
        }
    )
]


@app.list_tools()
async def list_tools() -> list[Tool]:
    """List all available tools"""
    logger.info("Listing available tools")
    return TOOLS


@app.call_tool()
async def call_tool(name: str, arguments: Any) -> list[TextContent]:
    """Handle tool calls"""
    logger.info(f"Tool called: {name} with arguments: {arguments}")
    
    try:
        if name == "echo":
            message = arguments.get("message", "")
            return [TextContent(
                type="text",
                text=f"Echo: {message}"
            )]
        
        elif name == "get_environment":
            prefix = arguments.get("prefix", "")
            env_vars = {
                k: v for k, v in os.environ.items()
                if k.startswith(prefix) and not any(
                    sensitive in k.lower() 
                    for sensitive in ['password', 'secret', 'key', 'token']
                )
            }
            return [TextContent(
                type="text",
                text=json.dumps(env_vars, indent=2)
            )]
        
        elif name == "health_check":
            health_status = {
                "status": "healthy",
                "server": "azure-mcp-server",
                "version": "1.0.0",
                "environment": os.environ.get("ENVIRONMENT", "production")
            }
            return [TextContent(
                type="text",
                text=json.dumps(health_status, indent=2)
            )]
        
        elif name == "calculate":
            operation = arguments.get("operation")
            a = float(arguments.get("a", 0))
            b = float(arguments.get("b", 0))
            
            if operation == "add":
                result = a + b
            elif operation == "subtract":
                result = a - b
            elif operation == "multiply":
                result = a * b
            elif operation == "divide":
                if b == 0:
                    return [TextContent(
                        type="text",
                        text="Error: Division by zero"
                    )]
                result = a / b
            else:
                return [TextContent(
                    type="text",
                    text=f"Error: Unknown operation '{operation}'"
                )]
            
            return [TextContent(
                type="text",
                text=f"Result: {result}"
            )]
        
        else:
            return [TextContent(
                type="text",
                text=f"Error: Unknown tool '{name}'"
            )]
    
    except Exception as e:
        logger.error(f"Error executing tool {name}: {str(e)}")
        return [TextContent(
            type="text",
            text=f"Error: {str(e)}"
        )]


async def main():
    """Main entry point for the MCP server"""
    logger.info("Starting Azure MCP Server...")
    
    # Run the server using stdio transport
    async with stdio_server() as (read_stream, write_stream):
        await app.run(
            read_stream,
            write_stream,
            app.create_initialization_options()
        )


if __name__ == "__main__":
    # Run the server
    asyncio.run(main())
