#!/usr/bin/with-contenv bash
# shellcheck shell=bash

echo "Initializing claude-code environment..."

# This script runs as the abc user (with PUID/PGID applied)
# All directories should already exist with proper permissions

# Set up git global config if not already done
if [ ! -f ~/.gitconfig ]; then
    git config --global user.name "Code Server User"
    git config --global user.email "user@codeserver.local"
fi

# Check if claude-code is available
if command -v claude >/dev/null 2>&1; then
    echo "Claude-code CLI is installed and ready for manual login"
    echo "To authenticate, run: claude auth login"
else
    echo "Warning: claude-code CLI not found"
fi

# Docker socket status
if [ -S /var/run/docker.sock ]; then
    echo "Docker socket detected and accessible"
    if groups | grep -q docker; then
        echo "User is in docker group"
    else
        echo "Warning: User may not have docker access"
    fi
fi

echo "Claude-code environment initialized successfully!"
echo "Workspace directory: /config/workspace"