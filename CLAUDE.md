# Docker Code-Server with Claude Code - Project Documentation

## Project Overview

This is a Docker-based development environment that combines LinuxServer's code-server image with Claude Code CLI and essential development tools. The project provides a web-based VS Code interface with integrated Claude AI assistance capabilities.

### Key Components:
- **Base Image**: LinuxServer's code-server (ghcr.io/linuxserver/code-server:latest)
- **Claude Code**: Anthropic's CLI tool for AI-powered coding assistance
- **Development Tools**: Docker CLI, GitHub CLI, Node.js, npm, and various utilities
- **Init System**: Uses s6-overlay for proper process supervision and permissions handling

## Project Structure

```
docker-code-server/
├── Dockerfile                 # Multi-stage Docker build configuration
├── docker-compose.yml         # Docker Compose configuration
├── README.md                  # User-facing documentation
├── .dockerignore             # Docker build exclusions
├── root/                     # s6-overlay service definitions
│   ├── defaults/
│   │   └── startup.sh        # User initialization script
│   └── etc/s6-overlay/
│       └── s6-rc.d/          # s6 service definitions
│           ├── init-claude-code-config/  # Root initialization service
│           └── svc-claude-code-startup/  # User startup service
├── config/                   # Empty, used as mount point
├── scripts/                  # Empty, populated at runtime
└── CLAUDE.md                 # This file
```

## Build and Development Commands

### Building the Image
```bash
docker build -t code-server-claude .
```

### Running with Docker Compose
```bash
docker-compose up -d
```

### Running with Docker CLI
```bash
docker run -d \
  --name=code-server-claude \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -p 8443:8443 \
  -v ./config:/config \
  -v ./workspace:/config/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  ghcr.io/yourusername/docker-code-server:latest
```

### Accessing the Environment
- Web Interface: http://localhost:8443
- Terminal: Available through the web interface
- Claude Code: Run `claude auth login` in terminal to authenticate

## Technical Details

### Initialization Process

The container uses LinuxServer's s6-overlay init system with two custom services:

1. **init-claude-code-config** (runs as root, after LinuxServer's init-adduser):
   - Creates application-specific directories (/config/.claude, /config/.npm, /config/scripts, /config/workspace)
   - Sets up Docker socket access by adding user to docker group
   - Copies default startup script if not present
   - Relies on LinuxServer base image to handle PUID/PGID ownership of /config

2. **svc-claude-code-startup** (runs as user):
   - Executes user-level initialization
   - Sets up default git configuration
   - Verifies Claude Code and Docker access

**Important Note on s6-overlay Integration:**
The Dockerfile uses `touch` commands to add custom services to the base image's `user` bundle rather than copying a complete user bundle directory. This prevents overwriting the base image's essential init services (including PUID/PGID handling). The custom services are added after copying the service definitions, ensuring both base and custom services execute properly.

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| PUID | User ID for file permissions | 1000 |
| PGID | Group ID for file permissions | 1000 |
| TZ | Container timezone | Etc/UTC |
| PASSWORD | Code-server web password | - |
| SUDO_PASSWORD | Sudo password for terminal | - |
| DEFAULT_WORKSPACE | Default workspace path | /config/workspace |

### Volume Mounts

| Path | Purpose | Notes |
|------|---------|-------|
| /config | Persistent configuration | Contains .claude/, scripts/, and user data |
| /config/workspace | Project workspace | Default working directory |
| /var/run/docker.sock | Docker socket | Read-only, for Docker CLI access |

### Installed Tools

**Core Development Tools:**
- Docker CLI (docker-ce-cli)
- GitHub CLI (gh)
- Node.js & npm
- Git

**Claude Integration:**
- claude-code CLI (@anthropic-ai/claude-code npm package)
- Authentication via `claude auth login`
- Configuration stored in /config/.claude/

## Security Considerations

1. **Docker Socket**: Mounted read-only by default. User added to docker group for access.
2. **File Permissions**: Uses PUID/PGID for proper ownership of mounted volumes.
3. **Authentication**: Claude Code requires manual authentication via web browser.
4. **Network**: Runs on port 8443, should be secured with proper firewall rules.

## Development Workflow

### For Container Development:
1. Modify Dockerfile or s6 service scripts
2. Build locally: `docker build -t code-server-claude .`
3. Test with docker-compose
4. Submit changes via GitHub PR

### For Using the Container:
1. Start container with docker-compose
2. Access web interface at http://localhost:8443
3. Open terminal and run `claude auth login`
4. Start coding with Claude assistance

## GitHub Actions Integration

The project includes workflows for:
- Automated builds on upstream image updates
- Multi-architecture support (AMD64, ARM64)
- Publishing to GitHub Container Registry
- Layer caching for faster builds

## Common Issues and Solutions

### Claude Code Authentication
- Issue: Can't authenticate with Claude
- Solution: Run `claude auth login` and follow browser prompts

### Docker Commands Not Working
- Issue: Permission denied on docker commands
- Solution: Verify docker socket is mounted and user is in docker group

### File Permission Issues
- Issue: Can't write to mounted volumes
- Solution: Adjust PUID/PGID to match host user (`id $USER`)

## Notes for AI Assistants

When working with this codebase:
1. The container uses s6-overlay for init - services must follow s6 conventions
2. All user-facing directories should respect PUID/PGID settings
3. Claude Code is installed via npm globally, not as a binary
4. Docker socket access requires proper group membership setup
5. The base image handles most user/permission management automatically
6. **Critical:** Never copy a complete `user/contents.d/` directory in the Dockerfile as it will overwrite the base image's service bundle and break PUID/PGID functionality. Always use `RUN touch` commands to add custom services to the existing bundle

## Project Type: Docker Development Environment

This is a Dockerfile project that creates a development container. Key considerations:
- Not a traditional application with package.json or requirements.txt
- Configuration is done through environment variables and volume mounts
- No build/test commands beyond Docker build
- Primary purpose is providing an integrated development environment