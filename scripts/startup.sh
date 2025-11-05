#!/bin/bash

echo "Initializing claude-code environment..."

# Claude-code CLI is installed and ready for manual login

# Set up git global config if not already done
if [ ! -f ~/.gitconfig ]; then
    git config --global user.name "Code Server User"
    git config --global user.email "user@codeserver.local"
fi

# Create claude-code directory for user configuration
mkdir -p ~/.claude

# Set up docker permissions if docker socket is mounted
if [ -S /var/run/docker.sock ]; then
    echo "Docker socket detected. Setting up permissions..."
    # Note: In production, you'd handle this more securely
fi

# Create workspace directory if not exists
mkdir -p /config/workspace

echo "Claude-code environment initialized successfully!"