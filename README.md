# Enhanced Code-Server with Claude Code

A Docker image that enhances the [linuxserver/code-server](https://github.com/linuxserver/docker-code-server) with claude-code CLI and essential development tools.

## Features

- **Base**: Latest linuxserver/code-server image
- **Claude Code**: Full terminal version of claude-code installed and configured
- **Development Tools**:
  - Docker CLI & Docker Compose
  - GitHub CLI (gh)
  - Node.js, npm, Python3, pip
  - Git, ripgrep, fzf, bat, exa, tree
  - Build tools and development dependencies
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

## Using Claude Code

Once the container is running:

1. Open the integrated terminal in code-server
2. Run `claude-code auth login` to authenticate with your Claude.ai account
3. Follow the prompts to complete authentication
4. Run `claude-code` to start using the CLI with your subscription

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