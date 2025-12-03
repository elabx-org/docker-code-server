# Enhanced Code-Server with AI Coding Assistants

A Docker image that enhances the [linuxserver/code-server](https://github.com/linuxserver/docker-code-server) with AI coding assistants (Claude Code, OpenAI Codex & Google Gemini CLI) and essential development tools.

## Features

- **Base**: Latest linuxserver/code-server image
- **Claude Code**: Anthropic's AI coding assistant with terminal access
- **OpenAI Codex**: OpenAI's AI coding assistant (works with ChatGPT Plus/Pro/Team)
- **Google Gemini CLI**: Google's AI coding assistant with 1M token context window (free tier available)
- **Happy Coder**: Remote mobile access to Claude Code sessions with push notifications
- **GitHub Copilot**: Pre-installed GitHub Copilot and Copilot Chat extensions
- **Development Tools**:
  - Docker CLI & Docker Compose
  - GitHub CLI (gh)
  - Node.js, npm, Python3, pip (with OpenAI package pre-installed)
  - Git, ripgrep, fzf, bat, exa, tree
  - Build tools and development dependencies
- **Intelligent OAuth Helper**: Automatically converts localhost OAuth URLs to code-server proxy URLs for seamless authentication
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
# Edit .env with your preferences (GitHub repo, timezone, etc.)
# IMPORTANT: Set CODE_SERVER_URL for OAuth authentication to work
# Example: CODE_SERVER_URL=https://code.example.com
```

3. Start the container:
```bash
docker-compose up -d
```

4. Access code-server at `http://localhost:8443`

### Using Docker Run

```bash
docker run -d \
  --name=code-server-claude \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -p 8443:8443 \
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

### PUID/PGID Usage

This image uses LinuxServer.io's s6-overlay init system to properly handle user permissions. The `PUID` and `PGID` environment variables control the user and group IDs that code-server runs as, ensuring proper file permissions for mounted volumes.

To find your user's UID and GID:
```bash
id $USER
```

Example output:
```
uid=911(username) gid=1001(groupname) groups=1001(groupname),998(docker)
```

Then set `PUID=911` and `PGID=1001` in your environment.

## Volume Mounts

| Path | Description |
|------|-------------|
| `/config` | Code-server configuration and user data |
| `/config/workspace` | Default workspace directory |
| `/var/run/docker.sock` | Docker socket (read-only) for Docker commands |

## Using AI Coding Assistants

Once the container is running, open the integrated terminal in code-server.

### Using Claude Code

1. Authenticate with Claude Code:
   ```bash
   # Recommended: Token-based authentication (works with remote access)
   claude setup-token

   # Alternative: OAuth login (only works well when accessing via localhost)
   claude auth login
   ```
2. Run `claude` to start using Claude Code

### Using OpenAI Codex

1. **Set CODE_SERVER_URL** (if not done already):
   ```bash
   # In your .env file
   CODE_SERVER_URL=https://code.example.com  # Your actual code-server URL
   ```

2. Authenticate with Codex:
   ```bash
   # Run codex and select option 1 when prompted
   codex
   ```

3. Select "Sign in with ChatGPT" if you have ChatGPT Plus/Pro/Team
   - The browser helper automatically converts localhost URLs to proxy URLs
   - Click the converted URL in the terminal
   - Complete authentication in your browser
   - **OAuth works seamlessly** - no manual URL editing needed!
   - Usage included with your paid ChatGPT plan
   - No additional API costs

4. Or select "Provide your own API key" for pay-as-you-go billing
   - Set `OPENAI_API_KEY` in your `.env` file
   - Get your API key from https://platform.openai.com/api-keys

**Note**: All three AI assistants are available side-by-side. Use whichever fits your workflow!

### Using Google Gemini CLI

1. **Set CODE_SERVER_URL** (if not done already):
   ```bash
   # In your .env file
   CODE_SERVER_URL=https://code.example.com  # Your actual code-server URL
   ```

2. Authenticate with Gemini:
   ```bash
   # Run gemini and sign in when prompted
   gemini
   ```

3. **Free tier available** - No API key required for personal use:
   - 60 requests/min and 1,000 requests/day
   - Access to Gemini 2.5 Pro with 1M token context window
   - Built-in tools: Google Search, file operations, shell commands

4. Or use **API key authentication**:
   - Set `GOOGLE_API_KEY` in your `.env` file
   - Get your API key from https://aistudio.google.com/apikey

## Using Happy Coder (Remote Access)

Happy Coder enables remote monitoring and control of Claude Code from your mobile device:

1. **Authenticate Claude Code** (if not already done):
   ```bash
   claude setup-token
   ```

2. **Download the mobile app**: [iOS App Store](https://apps.apple.com/app/happy-coder), Google Play, or https://app.happy.engineering

3. **Pair CLI with mobile app**:
   ```bash
   # Generate QR code for pairing
   happy --auth
   ```
   Scan the QR code with your mobile app to connect

4. **Start using Happy**:
   ```bash
   # Run happy instead of claude
   happy
   ```

**Features**:
- Monitor Claude Code sessions remotely
- Receive push notifications when Claude needs permissions
- Switch seamlessly between mobile and desktop control (press any key to return to desktop)
- End-to-end encryption for code security

See the [CLAUDE.md](CLAUDE.md#remote-access-with-happy-coder) for detailed usage instructions.

## Using GitHub Copilot

GitHub Copilot and Copilot Chat are automatically installed on container startup (they're not available in Open VSX, so we install them directly from the VS Code Marketplace).

1. Open code-server in your browser
2. Open the Command Palette (Ctrl+Shift+P / Cmd+Shift+P)
3. Run "GitHub Copilot: Sign In"
4. Follow the device code authentication flow

**Note:** Requires a valid GitHub Copilot subscription.

## GitHub Authentication

### Method 1: GitHub CLI with OAuth (Recommended)
```bash
# Ensure CODE_SERVER_URL is set in your .env file first
gh auth login
```
The browser helper automatically converts localhost OAuth URLs to code-server proxy URLs. Just click the converted URL in the terminal and complete authentication in your browser - it works seamlessly!

**Alternative**: Select the device flow option to use a copy/paste code (works without CODE_SERVER_URL).

### Method 2: SSH Keys
```bash
# Copy your SSH keys to the config directory
cp ~/.ssh/id_rsa ./config/.ssh/
cp ~/.ssh/id_rsa.pub ./config/.ssh/

# In the container terminal, configure git
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

### Method 3: VS Code's Built-in GitHub Auth
1. Click the **Accounts** icon in the bottom-left of code-server
2. Select **"Sign in with GitHub"**
3. Follow the OAuth flow

**Note:** VS Code's GitHub authentication only works for UI features, not terminal commands.

## Installing VS Code Extensions

You can automatically install VS Code extensions on container startup using two methods:

### Method 1: Environment Variable (Simple)

Set the `VSCODE_EXTENSIONS` variable in your `.env` file with a comma-separated list:

```bash
VSCODE_EXTENSIONS=ms-python.python,dbaeumer.vscode-eslint,eamodio.gitlens
```

### Method 2: Extensions File (Recommended for many extensions)

Create a file at `./config/extensions.txt` with one extension ID per line:

```bash
# Copy the example file
cp extensions.txt.example config/extensions.txt

# Edit to add your extensions
nano config/extensions.txt
```

Example `extensions.txt`:
```
# Python Development
ms-python.python

# JavaScript/TypeScript
dbaeumer.vscode-eslint
esbenp.prettier-vscode

# Git
eamodio.gitlens
```

**Notes:**
- Extensions are installed from the [Open VSX marketplace](https://open-vsx.org/)
- Already installed extensions are skipped automatically
- Extensions persist in `/config/.local/share/code-server/extensions`
- You can combine both methods - environment variable and file

## Development

### Building Locally

```bash
docker build -t code-server-claude .
```

### Workflow

The GitHub workflow automatically:
- Checks for upstream image updates daily
- Builds multi-architecture images
- Pushes to GitHub Container Registry
- Caches build layers for faster builds

## Configuration

### Claude Code Config

Claude-code will store your authentication and configuration in `/config/.claude/` after you complete the login process. This directory is persistent across container restarts.

### SSH Keys

To use SSH keys with git:
```yaml
volumes:
  - ~/.ssh:/config/.ssh:ro
```

### Git Configuration

To persist git configuration:
```yaml
volumes:
  - ~/.gitconfig:/config/.gitconfig:ro
```

## Security Considerations

- The Docker socket is mounted read-only by default
- Consider using Docker-in-Docker for better isolation in production
- Use strong passwords for code-server authentication
- Authentication is handled through Claude.ai login (no API keys needed)

## Troubleshooting

### Claude Code Not Working
- Run `claude-code auth login` to authenticate with Claude.ai
- Check container logs: `docker logs code-server-claude`
- Ensure you have an active Claude Pro or Team subscription

### Docker Commands Not Working
- Verify `/var/run/docker.sock` is mounted
- Check docker daemon is running on host
- Ensure user has docker permissions

### Permission Issues
- Adjust `PUID` and `PGID` to match your user
- Check volume mount permissions

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [LinuxServer.io](https://linuxserver.io/) for the excellent base image
- [Anthropic](https://anthropic.com/) for Claude Code
- All the open-source tools included in this image