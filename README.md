# Enhanced Code-Server with AI Coding Assistants

A Docker image that enhances the [linuxserver/code-server](https://github.com/linuxserver/docker-code-server) with AI coding assistants and essential development tools.

## Features

- **Base**: Latest linuxserver/code-server image
- **Claude Code**: Anthropic's AI coding assistant (native installer with auto-updates)
- **Claude Code UI**: Web-based mobile/remote interface for Claude Code sessions (port 3001)
- **OpenAI Codex**: OpenAI's AI coding assistant (works with ChatGPT Plus/Pro/Team)
- **Google Gemini CLI**: Google's AI coding assistant with 1M token context window
- **Happy Coder**: Remote mobile access to Claude Code sessions with push notifications
- **GitHub Copilot**: Pre-installed GitHub Copilot and Copilot Chat extensions
- **Development Tools**:
  - Docker CLI
  - GitHub CLI (gh)
  - Node.js 20 LTS, npm, Python 3, pip
  - ripgrep, fd, tree, shellcheck
  - Build tools (gcc, make), htop, strace, iproute2
  - Playwright (on-demand browser install for E2E testing)
  - OpenAI Python package
- **Intelligent OAuth Helper**: Automatically converts localhost OAuth URLs to code-server proxy URLs
- **Auto-Updates**: Workflow automatically builds when upstream image updates
- **Multi-Architecture**: Supports both AMD64 and ARM64

## Quick Start

### Using Docker Compose (Recommended)

1. Clone this repository:
```bash
git clone https://github.com/yourusername/docker-code-server.git
cd docker-code-server
```

2. Copy and configure environment file:
```bash
cp .env.example .env
# Edit .env with your preferences
# IMPORTANT: Set CODE_SERVER_URL for OAuth authentication to work
# Example: CODE_SERVER_URL=https://code.example.com
```

3. Start the container:
```bash
docker-compose up -d
```

4. Access code-server at `http://localhost:8443`
5. Access Claude Code UI at `http://localhost:3001`

### Using Docker Run

```bash
docker run -d \
  --name=code-server-claude \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -p 8443:8443 \
  -p 3001:3001 \
  -v /path/to/config:/config \
  -v /path/to/workspace:/config/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  --restart unless-stopped \
  ghcr.io/yourusername/docker-code-server:latest
```

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `PUID` | User ID for file permissions | No | 1000 |
| `PGID` | Group ID for file permissions | No | 1000 |
| `TZ` | Timezone | No | Etc/UTC |
| `PASSWORD` | Code-server password | No | - |
| `SUDO_PASSWORD` | Sudo password | No | - |
| `VSCODE_EXTENSIONS` | Comma-separated extension IDs to install on startup | No | - |
| `OPENAI_API_KEY` | OpenAI API key for Codex CLI and Python package | No | - |
| `GOOGLE_API_KEY` | Google API key for Gemini CLI | No | - |
| `CODE_SERVER_URL` | Your code-server URL for OAuth proxy conversion | No | - |

### PUID/PGID Usage

This image uses LinuxServer.io's s6-overlay init system to properly handle user permissions. The `PUID` and `PGID` environment variables control the user and group IDs that code-server runs as, ensuring proper file permissions for mounted volumes.

To find your user's UID and GID:
```bash
id $USER
```

## Ports

| Port | Service |
|------|---------|
| 8443 | code-server (VS Code in browser) |
| 3001 | Claude Code UI (mobile/remote web interface) |

## Volume Mounts

| Path | Description |
|------|-------------|
| `/config` | Code-server configuration and user data |
| `/config/workspace` | Default workspace directory |
| `/var/run/docker.sock` | Docker socket (read-only) for Docker commands |

## Using AI Coding Assistants

Once the container is running, open the integrated terminal in code-server.

### Claude Code

```bash
# Authenticate (recommended for remote access)
claude setup-token

# Start using Claude Code
claude
```

### Claude Code UI (Mobile/Remote Access)

Claude Code UI starts automatically on port 3001 and provides a web interface for managing Claude Code sessions from any device, including mobile.

- Access at `http://your-server:3001`
- Add to home screen on iOS/Android for app-like experience
- Includes interactive chat, file browser, git controls, and xterm.js terminal

### OpenAI Codex

```bash
# Option 1: Sign in with ChatGPT Plus/Pro/Team
codex

# Option 2: Use API key
export OPENAI_API_KEY=your-key
codex
```

### Google Gemini CLI

```bash
# Option 1: Sign in with Google account (free tier: 60 req/min)
gemini

# Option 2: Use API key
export GOOGLE_API_KEY=your-key
gemini
```

### Happy Coder (Mobile Monitoring)

```bash
# Pair with mobile app
happy --auth

# Use instead of claude for remote monitoring
happy
```

Download the mobile app: [iOS App Store](https://apps.apple.com/app/happy-coder) or https://app.happy.engineering

### GitHub Copilot

GitHub Copilot and Copilot Chat are automatically installed on container startup from the VS Code Marketplace. Open the Command Palette (Ctrl+Shift+P) and run "GitHub Copilot: Sign In".

## Installing VS Code Extensions

### Environment Variable

```bash
VSCODE_EXTENSIONS=ms-python.python,dbaeumer.vscode-eslint,eamodio.gitlens
```

### Extensions File

Create `config/extensions.txt` with one extension ID per line:

```
# Python
ms-python.python

# JavaScript
dbaeumer.vscode-eslint
esbenp.prettier-vscode
```

Extensions are installed from the [Open VSX marketplace](https://open-vsx.org/) and persist across restarts.

## GitHub Authentication

```bash
# Recommended: GitHub CLI with OAuth
# Ensure CODE_SERVER_URL is set for proxy URL conversion
gh auth login

# Alternative: SSH keys
# Mount your SSH keys: -v ~/.ssh:/config/.ssh:ro
```

## Development

### Building Locally

```bash
docker build -t code-server-claude .
docker-compose up -d
docker logs code-server-claude
```

### Workflow

The GitHub workflow automatically:
- Checks for upstream image updates daily
- Builds multi-architecture images (AMD64, ARM64)
- Pushes to GitHub Container Registry

## Security Considerations

- Docker socket is mounted read-only by default
- Claude Code UI tools are disabled by default (enable in settings)
- Use strong passwords for code-server authentication

## Troubleshooting

- **Claude Code not working**: Run `claude setup-token` to authenticate
- **Docker commands not working**: Verify socket is mounted, check `groups` shows `docker`
- **Permission issues**: Adjust `PUID`/`PGID` to match your user
- **Extensions not installing**: Check IDs against [Open VSX](https://open-vsx.org/)
- **OAuth not working**: Set `CODE_SERVER_URL` in your `.env` file
- **Check logs**: `docker logs code-server-claude`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [LinuxServer.io](https://linuxserver.io/) for the excellent base image
- [Anthropic](https://anthropic.com/) for Claude Code
- [Siteboon](https://github.com/siteboon/claudecodeui) for Claude Code UI
