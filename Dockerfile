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

# Install claude-code CLI
RUN npm install -g @anthropic-ai/claude-code

# Create necessary directories
RUN mkdir -p /config/scripts /config/.claude

# Copy startup script
COPY scripts/startup.sh /config/scripts/startup.sh
RUN chmod +x /config/scripts/startup.sh

# Switch back to abc user
USER abc

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