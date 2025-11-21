# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Docker-based development environment that combines LinuxServer's code-server image with AI coding assistants (Claude Code and OpenAI Codex). This is a **Dockerfile project** - not a traditional application with package.json or requirements.txt. The primary deliverable is a container image, not compiled code.

### Runtime Environment

- **Node.js**: 20.x LTS (from NodeSource)
- **npm**: 10.x (included with Node.js 20)
- **Why LTS**: Long-term support until April 2026, modern npm features for reliable auto-updates
- **Installation**: `Dockerfile:6-9` uses NodeSource repository for official binaries

### OpenAI Integration

The container includes the OpenAI Python package pre-installed for AI development:

- **Package**: `openai` (latest version via pip)
- **Python**: 3.x with pip and venv support
- **Installation**: `Dockerfile:33-36` installs Python, pip, and the OpenAI package globally
- **Authentication**: Set `OPENAI_API_KEY` environment variable in `.env` file
- **Usage**: Import in Python scripts: `import openai`
- **Verification**: Startup script checks OpenAI package availability and displays version

**Getting your API key:**
1. Visit https://platform.openai.com/api-keys
2. Create or copy your API key
3. Add to `.env` file: `OPENAI_API_KEY=sk-...`
4. Restart container: `docker-compose restart`

## Build and Test Commands

### Build the Docker image locally
```bash
docker build -t code-server-claude .
```

### Run the container
```bash
# Using docker-compose (recommended)
docker-compose up -d

# Using docker run
docker run -d \
  --name=code-server-claude \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -p 8443:8443 \
  -v ./config:/config \
  -v ./workspace:/config/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  code-server-claude
```

### Check container logs
```bash
docker logs code-server-claude
```

### Access the environment
- Web interface: http://localhost:8443
- Terminal: Open terminal in web interface
- Claude Code authentication: Run `claude setup-token` in terminal
- OpenAI Codex authentication: Run `codex` and select "Sign in with ChatGPT" (for Plus/Pro/Team)
- GitHub authentication: Run `gh auth login` in terminal
- Happy Coder (optional): Run `happy` instead of `claude` for remote mobile access

## Architecture

### Init System: s6-overlay Integration

This project uses LinuxServer.io's s6-overlay init system with **two custom services** that integrate into the base image's service bundle:

**1. init-claude-code-config** (runs as root, oneshot)
- **Dependencies**: Runs after `init-adduser`, `init-config`, and `init-mods-end` from base image
- **Location**: `root/etc/s6-overlay/s6-rc.d/init-claude-code-config/run`
- **Purpose**: Creates application directories and configures Docker socket access
- **Actions**:
  - Creates `/config/.claude`, `/config/.npm`, `/config/.npm-global`, `/config/scripts`, `/config/workspace`
  - Sets ownership on created directories using `chown "${PUID}:${PGID}"`
  - Adds `abc` user to docker group for socket access
  - Copies default startup script to `/config/scripts/startup.sh`
- **Note**: Must explicitly set ownership since it runs after base image's init phase

**2. svc-claude-code-startup** (runs as user `abc`, oneshot)
- **Dependencies**: Runs after `init-claude-code-config`
- **Location**: `root/etc/s6-overlay/s6-rc.d/svc-claude-code-startup/run`
- **Purpose**: User-level initialization
- **Actions**: Executes `/config/scripts/startup.sh` as the `abc` user
- **Script tasks**:
  - Sets up default git config
  - Configures npm to use `/config/.npm-global` for global packages
  - Installs Claude Code, OpenAI Codex, and Happy Coder to `/config/.npm-global` if not present
  - Creates auto-update config at `/config/.claude/config.json`
  - Verifies Claude Code, Codex, Happy Coder, and Docker access
  - Installs VS Code extensions from `VSCODE_EXTENSIONS` env var or `/config/extensions.txt` file

### Critical Implementation Detail: Service Bundle Integration

In `Dockerfile:45-46`, custom services are added to the base image's `user` bundle using:
```dockerfile
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/init-claude-code-config && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/svc-claude-code-startup
```

**Why this matters**:
- LinuxServer's base image has its own services in the `user` bundle, including critical PUID/PGID handling
- Copying a complete `user/contents.d/` directory would overwrite those services and break permission management
- Using `touch` adds our services alongside the base image's services rather than replacing them
- This ensures both base image services AND custom services execute during container initialization

### PUID/PGID Permission Model

The base image handles PUID/PGID ownership of existing `/config` contents during its init phase. However, custom services that run AFTER the base image's init must explicitly set ownership on any new directories they create:
- Use `mkdir -p` to create directories
- Use `chown "${PUID}:${PGID}"` to set ownership on created directories
- PUID and PGID environment variables are available via the `with-contenv` shebang
- This is necessary because our init service runs after the base image's ownership pass

## File Structure

```
root/
├── defaults/
│   └── startup.sh                              # User startup script template
└── etc/s6-overlay/s6-rc.d/
    ├── init-claude-code-config/                # Root init service
    │   ├── dependencies.d/                     # Runs after these base services
    │   │   ├── init-adduser
    │   │   ├── init-config
    │   │   └── init-mods-end
    │   ├── run                                 # The actual init script
    │   ├── type                                # "oneshot"
    │   └── up                                  # Empty (successful completion)
    └── svc-claude-code-startup/                # User startup service
        ├── dependencies.d/
        │   └── init-claude-code-config         # Runs after root init
        ├── run                                 # Executes startup.sh as abc user
        ├── type                                # "oneshot"
        └── up                                  # Empty (successful completion)
```

## Key Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| PUID | User ID for file permissions | 1000 |
| PGID | Group ID for file permissions | 1000 |
| TZ | Container timezone | Etc/UTC |
| PASSWORD | Code-server web password | - |
| SUDO_PASSWORD | Sudo password for terminal | - |
| DEFAULT_WORKSPACE | Default workspace path | /config/workspace |
| PROXY_DOMAIN | Domain for subdomain proxying | - |
| VSCODE_EXTENSIONS | Comma-separated list of extension IDs | - |
| OPENAI_API_KEY | OpenAI API key for using OpenAI services | - |
| CODE_SERVER_URL | Your code-server URL for OAuth proxy conversion (e.g., https://code.example.com) | - |

## Volume Mounts

| Container Path | Purpose | Notes |
|----------------|---------|-------|
| /config | Persistent configuration | All user data, .claude/ config |
| /config/workspace | Project workspace | Default working directory |
| /var/run/docker.sock | Docker socket | Read-only, for Docker CLI access |

## Claude Code Configuration

Claude Code is installed in `/config/.npm-global` and runs as the `abc` user. This allows Claude Code to auto-update itself without requiring Docker image rebuilds. Since `/config` is a persistent volume owned by the `abc` user, updates persist across container restarts.

**Installation Architecture**:
- **Build time** (`Dockerfile:34-38`): npm installs Claude Code globally (provides initial binary for first boot)
- **Runtime init** (`root/etc/s6-overlay/s6-rc.d/init-claude-code-config/run:15`): Creates `/config/.npm-global` directory with proper ownership
- **Startup script** (`root/defaults/startup.sh:15-24`):
  - Configures npm prefix to `/config/.npm-global`
  - Installs Claude Code to `/config/.npm-global` if not present
  - Adds `/config/.npm-global/bin` to PATH in `~/.bashrc`

**Auto-update Configuration**:
A configuration file is automatically created at `/config/.claude/config.json`:

```json
{
  "installationMethod": "npm-global",
  "autoUpdate": true
}
```

**Why this architecture**:
- `/config` is already owned by the `abc` user (no permission issues)
- `/config` is a persistent volume (updates survive container restarts)
- Auto-updates work without permission errors
- Users get the latest Claude Code features automatically
- No need for Docker image rebuilds to update Claude Code
- Setting `installationMethod: "npm-global"` eliminates diagnostic warnings

**Implementation**: The startup script (`root/defaults/startup.sh:31-42`) creates this config file if it doesn't exist during container initialization.

## OpenAI Codex Configuration

OpenAI Codex CLI is installed in `/config/.npm-global` alongside Claude Code, using the same auto-update architecture.

**Installation Architecture**:
- **Startup script** (`root/defaults/startup.sh:34-45`): Installs Codex CLI to `/config/.npm-global` if not present
- **Auto-updates**: Codex can auto-update itself since it's in the user-writable `/config` volume
- **PATH**: Added to `~/.bashrc` automatically

**Authentication Options**:
Codex offers two authentication methods:

1. **Sign in with ChatGPT (Recommended for ChatGPT Plus/Pro/Team users)**:
   ```bash
   codex
   ```
   - Select "Sign in with ChatGPT" when prompted
   - Usage included with your ChatGPT Plus, Pro, or Team plan
   - No additional API costs

2. **Use OpenAI API Key (Pay-as-you-go)**:
   - Set `OPENAI_API_KEY` in your `.env` file
   - Get your API key from https://platform.openai.com/api-keys
   - Billed separately based on usage

**Why this architecture**:
- Same benefits as Claude Code installation (persistent, auto-updating)
- Users can choose between ChatGPT subscription or API billing
- Both AI assistants (Claude & Codex) available side-by-side

## Browser Helper for OAuth in Containers

This container includes an intelligent browser helper (`/usr/local/bin/browser-helper`) that **automatically converts localhost OAuth callback URLs to code-server proxy URLs**, enabling seamless OAuth authentication for CLI tools in containerized environments.

**The Problem**: CLI tools that use OAuth open `http://localhost:PORT/callback` URLs. In a Docker container accessed remotely (e.g., `https://code.example.com`), these localhost URLs don't work because:
- Your browser is on your host machine
- The OAuth callback server is inside the container
- The localhost URL points to YOUR machine, not the container

**The Solution - Automatic URL Conversion**:
- **Location**: `root/usr/local/bin/browser-helper`
- **Installation**: `Dockerfile:45` makes the script executable
- **Configuration**:
  - `root/defaults/startup.sh:52-57` sets `BROWSER` environment variable
  - Set `CODE_SERVER_URL` in `.env` (e.g., `CODE_SERVER_URL=https://code.example.com`)
- **How it works**:
  1. CLI tool tries to open `http://localhost:11003/callback?code=abc`
  2. Browser helper automatically converts to: `https://code.example.com/proxy/11003/callback?code=abc`
  3. Displays the converted URL as a clickable link in terminal
  4. You click the link - OAuth completes successfully through code-server's built-in proxy!

**Configuration Example**:
```bash
# In your .env file
CODE_SERVER_URL=https://code.elabx.app

# Then OAuth authentication works seamlessly:
codex                    # Select "Sign in with ChatGPT"
gh auth login           # Select "Login with a web browser"
```

**Supported Tools**:
- `gh auth login` - GitHub CLI OAuth (browser flow)
- `codex` - OpenAI Codex sign-in with ChatGPT
- Any CLI tool that uses localhost OAuth callbacks and respects `BROWSER` environment variable

**Technical Details**:
- Converts both `localhost:PORT` and `127.0.0.1:PORT` patterns
- Preserves query parameters and paths in the conversion
- Works with code-server's built-in `/proxy/PORT/` feature
- Handles trailing slashes correctly
- Falls back to displaying original URL if `CODE_SERVER_URL` is not set

**Without CODE_SERVER_URL**: The helper still displays URLs clearly with instructions to manually convert them to proxy URLs.

**Alternative Methods**: Token-based authentication (`claude setup-token`, device flow) works without the browser helper.

## Remote Access with Happy Coder

This container includes [Happy Coder](https://github.com/slopus/happy), which enables remote monitoring and control of Claude Code sessions from mobile devices with end-to-end encryption.

### Features
- Monitor Claude Code sessions from iOS, Android, or web
- Receive push notifications when Claude needs permissions or encounters errors
- Seamlessly switch between mobile and desktop control
- End-to-end encryption keeps your code secure

### Usage
Instead of running `claude`, use the `happy` wrapper:

```bash
# Standard usage
happy

# The happy wrapper works exactly like claude but adds remote capabilities
# Press any key on your desktop to return control from mobile
```

### Setup

1. **Authenticate Claude Code** (if not already done):
   ```bash
   claude setup-token
   ```

2. **Download the mobile app**:
   - iPhone/iPad: [iOS App Store](https://apps.apple.com/app/happy-coder)
   - Android: Google Play
   - Web: https://app.happy.engineering

3. **Pair your CLI with the mobile app**:
   ```bash
   # Generate QR code for pairing
   happy --auth
   ```
   - The command displays a QR code and secret code
   - Scan the QR code with your mobile app to establish the connection
   - Alternatively, manually enter the secret code in the app

4. **Start using Happy**:
   ```bash
   # Run happy instead of claude
   happy
   ```

5. **Control switching**:
   - Press any key on your desktop keyboard to take back control from mobile
   - The session seamlessly switches between local and remote mode

### When to Use Happy Coder
- Monitor long-running AI tasks while away from your desk
- Get notified when Claude needs permission to proceed
- Review and approve changes from your phone
- Useful for keeping tabs on containerized development sessions

## VS Code Extensions

Extensions can be installed automatically on container startup:

### Method 1: Environment Variable
Set `VSCODE_EXTENSIONS` in `.env`:
```bash
VSCODE_EXTENSIONS=ms-python.python,dbaeumer.vscode-eslint,eamodio.gitlens
```

### Method 2: Extensions File
Create `/config/extensions.txt` with one extension ID per line:
```
# Python
ms-python.python

# Git
eamodio.gitlens
```

**Technical details:**
- Extensions installed via `code-server --install-extension <id>`
- Installed during startup script execution (runs as `abc` user)
- Extensions stored in `/config/.local/share/code-server/extensions`
- Installation happens in startup script after Claude Code and Happy Coder setup
- Already installed extensions skipped automatically

## Development Workflow

When modifying this container:

1. **For Dockerfile changes**: Build locally, test with docker-compose, verify init sequence in logs
2. **For s6 service changes**:
   - Modify scripts in `root/etc/s6-overlay/s6-rc.d/`
   - Check dependencies are correct
   - Verify service runs at expected stage (root vs user context)
   - Never copy complete `user/contents.d/` directory in Dockerfile
3. **For startup script changes**: Modify `root/defaults/startup.sh`
4. **Testing**: Check container logs for init sequence, verify permissions with `ls -la /config/`
5. **For extension changes**: Test with small extension list first, check logs for installation output

### GitHub Workflow Build Behavior

The `.github/workflows/build.yml` workflow automatically builds and pushes images with the following logic:

**When builds happen:**
- **Push to main/develop**: Always builds (regardless of upstream changes)
- **Pull requests**: Always builds (for testing)
- **Manual trigger**: Respects `force_build` parameter
- **Scheduled (daily at 2 AM UTC)**: Only builds if upstream `linuxserver/code-server:latest` has changed

**Why this design:**
- Code changes (push/PR) should always trigger builds to test your modifications
- Scheduled runs avoid unnecessary daily builds when nothing has changed
- Manual triggers give you control when needed

**Location**: `.github/workflows/build.yml:62-75`

## Common Issues

### OAuth Authentication in Container

**✅ Solution - Automatic URL Conversion (Configured)**:
Set `CODE_SERVER_URL` in your `.env` file to enable automatic localhost-to-proxy URL conversion:

```bash
# In .env
CODE_SERVER_URL=https://code.elabx.app
```

After setting this, OAuth authentication works seamlessly:
1. Run `codex` or `gh auth login`
2. The browser helper automatically converts `localhost:PORT` to `CODE_SERVER_URL/proxy/PORT/`
3. Click the converted URL in the terminal
4. Complete authentication in your browser
5. Done! OAuth callback completes successfully

**Supported OAuth Flows**:
- `gh auth login` - GitHub CLI (browser flow)
- `codex` - OpenAI Codex with ChatGPT sign-in
- Any CLI tool using localhost OAuth callbacks

**If OAuth still doesn't work**:
1. **Verify CODE_SERVER_URL**: Must match your actual code-server URL (including https://)
2. **Check code-server accessibility**: Ensure `/proxy/PORT/` paths work (test with a simple HTTP server)
3. **Alternative - Device Flow**: Use `gh auth login` and select device flow (copy/paste code)
4. **Alternative - Token Auth**: Use `claude setup-token` or API keys

**Technical Note**: The `BROWSER` environment variable is automatically set to `/usr/local/bin/browser-helper` which intelligently converts localhost URLs and displays clickable links in code-server's terminal

### Claude Code authentication fails
- Use `claude setup-token` for token-based authentication
- Check `/config/.claude/` exists and has correct ownership (run `ls -la /config/.claude`)

### Docker commands fail with permission denied
- Verify `/var/run/docker.sock` is mounted
- Check user is in docker group: `groups` should show `docker`
- Service `init-claude-code-config` should add user to group at init

### File permission issues on mounted volumes
- Verify PUID/PGID match host user: `id $USER` on host
- Check base image's init ran: look for "GID/UID" messages in container logs
- Verify init-claude-code-config set ownership: look for "Setting ownership" message in logs
- If `/config/.claude` or other dirs are owned by root, the init service needs to run `chown`

### Changes to s6 services not taking effect
- Rebuild image completely: `docker-compose build --no-cache`
- Verify services added to user bundle with `touch` command in Dockerfile
- Check for typos in dependency file names

### Extensions not installing
- Check container logs: `docker logs code-server-claude | grep -i extension`
- Verify extension IDs are correct (check [Open VSX](https://open-vsx.org/))
- Check `/config/extensions.txt` has correct format (one per line, no commas)
- Manually test: `docker exec -it code-server-claude code-server --install-extension <id>`
- Extensions persist in `/config/.local/share/code-server/extensions`
