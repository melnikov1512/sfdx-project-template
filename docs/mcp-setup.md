# Recommended MCP Servers

This guide lists MCP servers that enhance Copilot when working on this Salesforce DX project, and shows how to configure them for **VS Code** and **JetBrains**.

> **Why global, not workspace-level?**
> VS Code runs both global and workspace MCP configs simultaneously with no override mechanism, which results in duplicate tools for anyone who already has servers configured globally. Managing servers globally avoids this.

---

## Recommended servers

| Server            | Why it helps                                                      |
| ----------------- | ----------------------------------------------------------------- |
| **Salesforce DX** | Deploy/retrieve metadata, run Apex tests, query data from the org |
| **GitHub MCP**    | Manage issues, PRs, and Actions without leaving chat              |
| **Context7**      | Up-to-date Apex, LWC, SLDS, and SF CLI docs on demand             |
| **Tavily**        | Search Salesforce Known Issues, Stack Exchange, release notes     |
| **filesystem**    | Read/write project files directly from chat                       |
| **fetch**         | Pull any URL (WSDL, API specs, docs pages) into context           |
| **memory**        | Persist architectural decisions across sessions                   |
| **Playwright**    | Browser automation for LWC E2E testing                            |

---

## IDE-specific setup

### VS Code

Official docs: [Add and manage MCP servers in VS Code](https://code.visualstudio.com/docs/copilot/customization/mcp-servers)

Edit your **user-level** config (available across all workspaces):

1. Open the Command Palette (`Cmd+Shift+P`)
2. Run **MCP: Open User Configuration**
3. Paste the [complete example](#complete-examples) below

For workspace-level sharing, create `.vscode/mcp.json` in the project root and commit it. Use `inputs` to avoid hardcoding secrets — VS Code will prompt once and store them in the system keychain.

---

### JetBrains

Official docs: [Extending Copilot Chat with MCP — JetBrains section](https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp-in-your-ide/extend-copilot-chat-with-mcp?tool=jetbrains)

Config file path: `~/.config/github-copilot/intellij/mcp.json`

Uses the same `{ "servers": { ... } }` format as VS Code (no `inputs` support — use environment variables for secrets).

---

## Complete examples

### VS Code — `~/.config/Code/User/mcp.json` (macOS: `~/Library/Application Support/Code/User/mcp.json`)

```json
{
    "inputs": [
        {
            "id": "github-token",
            "type": "promptString",
            "description": "GitHub Personal Access Token",
            "password": true
        },
        {
            "id": "tavily-api-key",
            "type": "promptString",
            "description": "Tavily API Key",
            "password": true
        },
        {
            "id": "context7-api-key",
            "type": "promptString",
            "description": "Context7 API Key",
            "password": true
        }
    ],
    "servers": {
        "Salesforce DX": {
            "command": "npx",
            "args": [
                "-y",
                "@salesforce/mcp",
                "--orgs",
                "DEFAULT_TARGET_ORG",
                "--toolsets",
                "orgs,metadata,data,users",
                "--tools",
                "run_apex_test",
                "--allow-non-ga-tools"
            ]
        },
        "fetch": {
            "command": "uvx",
            "args": ["mcp-server-fetch"]
        },
        "filesystem": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/your/projects"]
        },
        "memory": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-memory"]
        },
        "io.github.upstash/context7": {
            "type": "stdio",
            "command": "npx",
            "args": ["-y", "@upstash/context7-mcp@latest"],
            "env": {
                "CONTEXT7_API_KEY": "${input:context7-api-key}"
            }
        },
        "microsoft/playwright-mcp": {
            "type": "stdio",
            "command": "npx",
            "args": ["-y", "@playwright/mcp@latest"]
        },
        "io.github.github/github-mcp-server": {
            "type": "http",
            "url": "https://api.githubcopilot.com/mcp/",
            "requestInit": {
                "headers": {
                    "Authorization": "Bearer ${input:github-token}"
                }
            }
        },
        "io.github.tavily-ai/tavily-mcp": {
            "type": "stdio",
            "command": "npx",
            "args": ["-y", "tavily-mcp@latest"],
            "env": {
                "TAVILY_API_KEY": "${input:tavily-api-key}"
            }
        }
    }
}
```

---

### JetBrains — `~/.config/github-copilot/intellij/mcp.json`

```json
{
    "servers": {
        "Salesforce DX": {
            "command": "npx",
            "args": [
                "-y",
                "@salesforce/mcp",
                "--orgs",
                "DEFAULT_TARGET_ORG",
                "--toolsets",
                "orgs,metadata,data,users",
                "--tools",
                "run_apex_test",
                "--allow-non-ga-tools"
            ]
        },
        "fetch": {
            "command": "uvx",
            "args": ["mcp-server-fetch"]
        },
        "filesystem": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/your/projects"]
        },
        "memory": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-memory"]
        },
        "io.github.upstash/context7": {
            "type": "stdio",
            "command": "npx",
            "args": ["-y", "@upstash/context7-mcp@latest"],
            "env": {
                "CONTEXT7_API_KEY": "YOUR_CONTEXT7_API_KEY"
            }
        },
        "microsoft/playwright-mcp": {
            "type": "stdio",
            "command": "npx",
            "args": ["-y", "@playwright/mcp@latest"]
        },
        "io.github.github/github-mcp-server": {
            "type": "http",
            "url": "https://api.githubcopilot.com/mcp/",
            "requestInit": {
                "headers": {
                    "Authorization": "Bearer YOUR_GITHUB_PAT"
                }
            }
        },
        "io.github.tavily-ai/tavily-mcp": {
            "type": "stdio",
            "command": "npx",
            "args": ["-y", "tavily-mcp@latest"],
            "env": {
                "TAVILY_API_KEY": "YOUR_TAVILY_API_KEY"
            }
        }
    }
}
```
