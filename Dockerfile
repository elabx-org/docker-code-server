FROM ghcr.io/linuxserver/code-server:latest

# Switch to root for installations
USER root

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    python3 \
    python3-pip \
    nodejs \
    npm \
    jq \
    vim \
    nano \
    htop \
    ncdu \
    tree \
    ripgrep \
    fd-find \
    bat \
    eza \
    fzf \
    tmux \
    zsh \
    openssh-client \
    gnupg2 \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Install claude-code CLI (official Anthropic version)
RUN npm install -g @anthropic-ai/claude-code

# Install additional development tools
RUN npm install -g \
    typescript \
    ts-node \
    nodemon \
    prettier \
    eslint \
    @types/node

# Install Python tools
RUN pip3 install --no-cache-dir \
    ipython \
    jupyter \
    black \
    flake8 \
    mypy \
    pytest \
    requests \
    pandas \
    numpy

# Create scripts directory
RUN mkdir -p /config/scripts

# Copy startup script
COPY scripts/startup.sh /config/scripts/startup.sh
RUN chmod +x /config/scripts/startup.sh

# Create claude-code directory (configuration will be done manually after login)
RUN mkdir -p /config/.claude

# Switch back to abc user
USER abc

# Set environment variables
ENV DOCKER_HOST="unix:///var/run/docker.sock"

# Add startup script to s6 services
RUN mkdir -p /etc/s6-overlay/s6-rc.d/claude-setup && \
    echo "oneshot" > /etc/s6-overlay/s6-rc.d/claude-setup/type && \
    echo "/config/scripts/startup.sh" > /etc/s6-overlay/s6-rc.d/claude-setup/up && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/claude-setup

# Expose code-server port
EXPOSE 8443

# Volume for docker socket
VOLUME /var/run/docker.sock

# Labels
LABEL maintainer="Your Name"
LABEL org.opencontainers.image.source="https://github.com/yourusername/docker-code-server"
LABEL org.opencontainers.image.description="Enhanced code-server with claude-code and development tools"