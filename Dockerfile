FROM ghcr.io/linuxserver/code-server:latest

# Switch to root for installations
USER root

# Install prerequisites and Node.js 20 LTS from NodeSource (provides modern npm 10.x)
RUN apt-get update && \
    apt-get install -y curl gnupg2 lsb-release && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install Docker CLI (for docker commands)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Install build dependencies for npm packages with native modules
# Also install jq for GitHub Copilot extension installer
# Claude Code and Happy Coder will be installed by the startup script
# to /config/.npm-global (user-writable, allows auto-updates)
# Also install Python and OpenAI package for AI development
# Install xdg-utils for browser helper support in containerized environment
RUN apt-get update && \
    apt-get install -y build-essential python3 python3-pip python3-venv xdg-utils jq \
    ripgrep fd-find tree shellcheck unzip zip htop strace iproute2 less && \
    rm -rf /var/lib/apt/lists/* && \
    pip3 install --no-cache-dir --break-system-packages openai playwright && \
    npm install -g playwright && \
    ln -sf "$(which fdfind)" /usr/local/bin/fd

# Copy the init scripts and defaults for claude-code setup
# The --chown=root:root ensures proper ownership for s6 scripts
# Scripts run from /defaults/ (in image), not /config/ (persistent volume)
COPY --chown=root:root root/ /

# Make helper scripts executable
RUN chmod +x /usr/local/bin/browser-helper /usr/local/bin/update-copilot

# Add our custom services to the user bundle (don't overwrite the base image's bundle)
# This ensures both base image and custom services run during initialization
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/init-claude-code-config && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/svc-claude-code-startup && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/svc-claude-code-ui

# No need to switch user - LinuxServer base handles this

# Set environment variables
ENV DOCKER_HOST="unix:///var/run/docker.sock"

# Expose code-server and Claude Code UI ports
EXPOSE 8443 3001

# Volume for docker socket
VOLUME /var/run/docker.sock

# Labels
LABEL maintainer="Your Name"
LABEL org.opencontainers.image.source="https://github.com/yourusername/docker-code-server"
LABEL org.opencontainers.image.description="Enhanced code-server with claude-code and development tools"
