FROM ghcr.io/linuxserver/code-server:latest

# Switch to root for installations
USER root

# Install only the absolute essentials
RUN apt-get update && apt-get install -y \
    curl \
    gnupg2 \
    lsb-release \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

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

# Install claude-code CLI with proper permissions
# The npm global directory needs to be accessible by the abc user
RUN npm install -g @anthropic-ai/claude-code && \
    # Ensure the global npm modules are readable by all users
    chmod -R 755 /usr/local/lib/node_modules/@anthropic-ai/claude-code && \
    # Ensure the claude binary is executable by all users
    chmod 755 /usr/local/bin/claude

# Copy the init scripts and defaults for claude-code setup
# The --chown=root:root ensures proper ownership for s6 scripts
COPY --chown=root:root root/ /

# Add our custom services to the user bundle (don't overwrite the base image's bundle)
# This ensures both base image and custom services run during initialization
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/init-claude-code-config && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/svc-claude-code-startup

# No need to switch user - LinuxServer base handles this

# Set environment variables
ENV DOCKER_HOST="unix:///var/run/docker.sock"

# Expose code-server port
EXPOSE 8443

# Volume for docker socket
VOLUME /var/run/docker.sock

# Labels
LABEL maintainer="Your Name"
LABEL org.opencontainers.image.source="https://github.com/yourusername/docker-code-server"
LABEL org.opencontainers.image.description="Enhanced code-server with claude-code and development tools"