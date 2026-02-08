# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Docker-based development environment that combines LinuxServer's code-server image with AI coding assistants (Claude Code, OpenAI Codex, Google Gemini CLI, and Happy Coder). This is a **Dockerfile project** - the primary deliverable is a container image published to `ghcr.io`.

**Base image**: `ghcr.io/linuxserver/code-server:latest`
**Runtime**: Node.js 20.x LTS (NodeSource), Python 3.x, Docker CLI, GitHub CLI
**Published to**: `ghcr.io/<owner>/docker-code-server:latest`

## Build and Test Commands

```bash
# Build locally
docker build -t code-server-claude .

# Run with docker-compose (recommended)
docker-compose up -d

# Check logs (primary way to verify init sequence)
docker logs code-server-claude

# Rebuild without cache (needed after s6 service changes)
docker-compose build --no-cache

# Access: http://localhost:8443
```

There are no unit tests, linters, or compilation steps. Testing means building the image and verifying the init sequence in container logs.

## Architecture

### Init System: s6-overlay (Two Custom Services)

The container uses LinuxServer.io's s6-overlay init system. The initialization chain is:

```
Base image services (init-adduser, init-config, init-mods-end)
  └─> init-claude-code-config  (root, oneshot)
        └─> svc-claude-code-startup  (user abc, oneshot)
```

**1. init-claude-code-config** — `root/etc/s6-overlay/s6-rc.d/init-claude-code-config/run`
- Runs as **root** after base image init completes
- Creates directories: `/config/.claude`, `/config/.codex`, `/config/.gemini`, `/config/.npm`, `/config/.npm-global`, `/config/scripts`, `/config/workspace`
- Sets ownership via `chown "${PUID}:${PGID}"` (required because this runs after base image's ownership pass)
- Adds `abc` user to docker group for socket access

**2. svc-claude-code-startup** — `root/etc/s6-overlay/s6-rc.d/svc-claude-code-startup/run`
- Runs as **user `abc`**, executes `/defaults/startup.sh`
- Configures npm prefix to `/config/.npm-global`
- Installs AI tools (Claude Code via native installer, Codex, Gemini CLI, Happy Coder via npm) if not present
- Installs VS Code extensions and GitHub Copilot
- Sets `BROWSER=/usr/local/bin/browser-helper` for OAuth flows

### Critical: Service Bundle Integration

In `Dockerfile:50-51`, services are registered using `touch`:
```dockerfile
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/init-claude-code-config && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/svc-claude-code-startup
```
**Never copy a complete `user/contents.d/` directory** — this would overwrite base image services and break PUID/PGID handling. Always use `touch` to add services alongside existing ones.

### PUID/PGID Permission Model

The base image handles ownership of existing `/config` contents during its init phase. Custom services that run **after** base init must explicitly `chown` any directories they create. PUID/PGID are available via the `with-contenv` shebang.

### Claude Code Native Install

Claude Code uses the official native installer (`curl -fsSL https://claude.ai/install.sh | bash`). The binary installs to `~/.local/bin/claude` (`/config/.local/bin/claude`) with data at `~/.local/share/claude`. Auto-updates happen in the background — no `config.json` needed. The npm installation method is deprecated.

### npm Global Install (Other Tools)

Happy Coder, Codex, and Gemini CLI install to `/config/.npm-global` (persistent volume, owned by `abc` user). This means:
- Tools auto-update without root or image rebuilds
- Updates persist across container restarts
- The startup script only installs if the binary doesn't exist (`[ ! -x /config/.npm-global/bin/<tool> ]`)
- PATH includes both `~/.local/bin` and `/config/.npm-global/bin` via `~/.bashrc`

npm packages: `happy-coder`, `@openai/codex`, `@google/gemini-cli`

### Browser Helper (OAuth in Containers)

`root/usr/local/bin/browser-helper` converts `localhost:PORT` OAuth callback URLs to code-server proxy URLs (`CODE_SERVER_URL/proxy/PORT/...`). Set `CODE_SERVER_URL` env var to enable. Without it, URLs are displayed as-is. The `BROWSER` env var is set in `startup.sh` to point to this script.

### GitHub Copilot Auto-Install

`root/defaults/install-copilot.sh` queries the VS Code Marketplace API to find the latest compatible Copilot/Copilot Chat versions, compares with installed versions, and downloads VSIX packages as needed. It runs at the end of `startup.sh` via `source`. Requires `jq` (installed in Dockerfile).

## Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Image build definition (68 lines) |
| `docker-compose.yml` | Container orchestration with env vars |
| `root/defaults/startup.sh` | Main user-level init script (runs as `abc`) |
| `root/defaults/install-copilot.sh` | Copilot extension installer/updater |
| `root/usr/local/bin/browser-helper` | OAuth URL converter for containerized env |
| `root/etc/s6-overlay/s6-rc.d/init-claude-code-config/run` | Root init (dirs, permissions, docker group) |
| `root/etc/s6-overlay/s6-rc.d/svc-claude-code-startup/run` | User init (calls startup.sh) |
| `.github/workflows/build.yml` | CI/CD: build + push to GHCR |
| `.claude/settings.local.json` | Pre-approved Claude Code permissions |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `PUID` / `PGID` | User/group ID for file permissions (default: 1000) |
| `PASSWORD` | Code-server web password |
| `SUDO_PASSWORD` | Sudo password for terminal |
| `VSCODE_EXTENSIONS` | Comma-separated extension IDs to install on startup |
| `OPENAI_API_KEY` | OpenAI API key (Codex CLI + Python package) |
| `GOOGLE_API_KEY` | Google API key for Gemini CLI |
| `CODE_SERVER_URL` | Your code-server URL for OAuth proxy conversion |
| `CODE_SERVER_BIN` | code-server binary path (default: `/app/code-server/bin/code-server`) |

## CI/CD Pipeline

`.github/workflows/build.yml` builds multi-arch images (`linux/amd64`, `linux/arm64`) and pushes to GHCR.

**Build triggers:**
- **Push to main/develop**: Always builds
- **Pull requests**: Always builds
- **Scheduled (daily 2 AM UTC)**: Only builds if upstream `linuxserver/code-server:latest` digest changed (cached via GitHub Actions cache)
- **Manual**: Respects `force_build` parameter

**Tagging strategy** (via `docker/metadata-action`):
- `latest` on default branch pushes
- Branch name on branch pushes
- `pr-N` on pull requests
- `<branch>-sha-<hash>` for every build
- Semver tags when applicable

## Development Workflow

1. **Dockerfile changes**: Build locally, test with `docker-compose up -d`, verify init in logs
2. **s6 service changes**: Modify scripts in `root/etc/s6-overlay/s6-rc.d/`, verify dependencies, never copy full `user/contents.d/`
3. **Startup script changes**: Edit `root/defaults/startup.sh`, rebuild and check logs
4. **Testing**: `docker logs code-server-claude` to verify init, `docker exec -it code-server-claude ls -la /config/` for permissions

## Common Issues

- **Permission issues**: Ensure any new directories created by init services get `chown "${PUID}:${PGID}"`. Base image only owns pre-existing `/config` contents.
- **s6 services not running**: Verify `touch` entries in Dockerfile and dependency files exist with correct names.
- **Extensions not installing**: Check extension IDs against [Open VSX](https://open-vsx.org/). Copilot comes from VS Code Marketplace (not Open VSX) via the custom installer.
- **OAuth not working**: Set `CODE_SERVER_URL` in `.env`. Fallback: use token auth (`claude setup-token`) or device flow.
- **Claude Code auth fails**: Run `claude setup-token`. Check `/config/.claude/` ownership.
- **Docker permission denied**: Verify socket is mounted, check `groups` shows `docker`.
