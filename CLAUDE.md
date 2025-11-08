# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Docker-based development environment that combines LinuxServer's code-server image with Claude Code CLI. This is a **Dockerfile project** - not a traditional application with package.json or requirements.txt. The primary deliverable is a container image, not compiled code.

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
- Claude authentication: Run `claude setup-token` in terminal
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
  - Creates `/config/.claude`, `/config/.npm`, `/config/scripts`, `/config/workspace`
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
  - Verifies Claude Code and Docker access
  - Installs VS Code extensions from `VSCODE_EXTENSIONS` env var or `/config/extensions.txt` file
  - Extensions are installed via `code-server --install-extension <id>`
  - Already installed extensions are skipped for efficiency

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

## Volume Mounts

| Container Path | Purpose | Notes |
|----------------|---------|-------|
| /config | Persistent configuration | All user data, .claude/ config |
| /config/workspace | Project workspace | Default working directory |
| /var/run/docker.sock | Docker socket | Read-only, for Docker CLI access |

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
1. **In the container terminal**: Authentication works the same as Claude Code
   ```bash
   # Authenticate Claude (if not already done)
   claude setup-token

   # Run happy instead of claude
   happy
   ```

2. **On your mobile device**:
   - Download Happy Coder from the [iOS App Store](https://apps.apple.com/app/happy-coder), Google Play, or use the web version
   - Connect to your session

3. **Control switching**:
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
- Installation happens in `root/defaults/startup.sh:33-66`
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

## Common Issues

### CLI OAuth redirects fail when accessing via domain
**Problem:** When accessing code-server through a custom domain, `gh auth login` or `claude auth login` try to redirect to `localhost:PORT` which fails

**Why this happens:**
1. CLI tools start OAuth callback servers on the container's `localhost:RANDOM_PORT`
2. They send the callback URL `http://localhost:PORT/callback` to the OAuth provider (GitHub/Claude)
3. After authentication, the provider redirects your browser to that URL
4. Your browser tries to connect to YOUR machine's localhost, not the container's localhost
5. The connection fails because the callback server is inside the container

**Why we can't fix this at the image level:**
- CLI tools don't expose configuration for custom callback URLs
- The OAuth provider only knows about the hardcoded `localhost:PORT` URL
- We can't intercept or modify the callback URL without modifying the CLI tools themselves

**Solutions (use these instead):**
- **GitHub CLI:** Use `gh auth login` - automatically uses device flow (copy/paste code)
- **Claude Code:** Use `claude setup-token` - token-based auth without OAuth callbacks
- **SSH Keys (GitHub only):** Copy SSH keys to `/config/.ssh/` and configure git manually

**The startup script now provides helpful guidance** when you open a terminal

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
