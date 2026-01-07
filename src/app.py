"""
Web wrapper for MCP Server to run on Azure Web App

This module provides an HTTP interface for the MCP server,
allowing it to be accessed via APIM and standard HTTP requests.
"""

import asyncio
import json
import logging
import os
from typing import Any

from flask import Flask, request, jsonify
from mcp.types import JSONRPCRequest, JSONRPCResponse, JSONRPCError

# Import the MCP server
from mcp_server import app as mcp_app, TOOLS

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create Flask app
flask_app = Flask(__name__)


class MCPWebAdapter:
    """Adapter to handle HTTP requests for MCP server"""
    
    def __init__(self, mcp_server):
        self.mcp_server = mcp_server
    
    async def handle_list_tools(self) -> dict:
        """Handle list tools request"""
        try:
            tools = await self.mcp_server.list_tools()
            return {
                "jsonrpc": "2.0",
                "result": {
                    "tools": [
                        {
                            "name": tool.name,
                            "description": tool.description,
                            "inputSchema": tool.inputSchema
                        }
                        for tool in tools
                    ]
                },
                "id": 1
            }
        except Exception as e:
            logger.error(f"Error listing tools: {str(e)}")
            return {
                "jsonrpc": "2.0",
                "error": {
                    "code": -32603,
                    "message": f"Internal error: {str(e)}"
                },
                "id": 1
            }
    
    async def handle_call_tool(self, tool_name: str, arguments: dict) -> dict:
        """Handle call tool request"""
        try:
            result = await self.mcp_server.call_tool(tool_name, arguments)
            return {
                "jsonrpc": "2.0",
                "result": {
                    "content": [
                        {
                            "type": item.type,
                            "text": item.text
                        }
                        for item in result
                    ]
                },
                "id": 1
            }
        except Exception as e:
            logger.error(f"Error calling tool {tool_name}: {str(e)}")
            return {
                "jsonrpc": "2.0",
                "error": {
                    "code": -32603,
                    "message": f"Internal error: {str(e)}"
                },
                "id": 1
            }


# Create adapter
adapter = MCPWebAdapter(mcp_app)


@flask_app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for Azure Web App"""
    return jsonify({
        "status": "healthy",
        "service": "mcp-server"
    }), 200


@flask_app.route('/api/v1/tools', methods=['GET'])
def list_tools():
    """List available tools endpoint"""
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        result = loop.run_until_complete(adapter.handle_list_tools())
        loop.close()
        return jsonify(result), 200
    except Exception as e:
        logger.error(f"Error in list_tools: {str(e)}")
        return jsonify({
            "error": str(e)
        }), 500


@flask_app.route('/api/v1/tools/call', methods=['POST'])
def call_tool():
    """Call a tool endpoint"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                "error": "No JSON data provided"
            }), 400
        
        tool_name = data.get('tool_name') or data.get('name')
        arguments = data.get('arguments', {})
        
        if not tool_name:
            return jsonify({
                "error": "Missing 'tool_name' or 'name' field"
            }), 400
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        result = loop.run_until_complete(
            adapter.handle_call_tool(tool_name, arguments)
        )
        loop.close()
        
        return jsonify(result), 200
    
    except Exception as e:
        logger.error(f"Error in call_tool: {str(e)}")
        return jsonify({
            "error": str(e)
        }), 500


@flask_app.route('/', methods=['GET'])
def root():
    """Root endpoint with API information"""
    return jsonify({
        "service": "MCP Server",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "list_tools": "/api/v1/tools",
            "call_tool": "/api/v1/tools/call"
        },
        "documentation": "https://modelcontextprotocol.io/"
    }), 200


if __name__ == '__main__':
    # Run Flask app
    # In production, this will be run by gunicorn
    port = int(os.environ.get('PORT', 8000))
    flask_app.run(host='0.0.0.0', port=port, debug=False)
