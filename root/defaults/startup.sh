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

# Configure npm to use /config/.npm-global for user-level global packages
# This allows Claude Code to auto-update without root permissions
export PATH="/config/.npm-global/bin:$PATH"
npm config set prefix /config/.npm-global

# Install Claude Code to /config/.npm-global if not already there
if [ ! -f /config/.npm-global/bin/claude ]; then
    echo "Installing Claude Code to /config/.npm-global for auto-updates..."
    npm install -g @anthropic-ai/claude-code happy-coder
fi

# Add /config/.npm-global/bin to PATH permanently for all shells
if [ ! -f ~/.bashrc ] || ! grep -q "/config/.npm-global/bin" ~/.bashrc; then
    echo 'export PATH="/config/.npm-global/bin:$PATH"' >> ~/.bashrc
fi

# Configure Claude Code for auto-updates
# Claude is installed in /config/.npm-global which is owned by the abc user
# This allows Claude Code to auto-update itself
if [ ! -f ~/.claude/config.json ]; then
    echo "Configuring Claude Code settings..."
    cat > ~/.claude/config.json <<'EOF'
{
  "installationMethod": "npm-global",
  "autoUpdate": true
}
EOF
fi

# Check if claude-code is available
if command -v claude >/dev/null 2>&1; then
    echo "Claude-code CLI is installed and ready for manual login"
    echo "To authenticate, run: claude setup-token"
else
    echo "Warning: claude-code CLI not found"
fi

# Check if happy-coder is available
if command -v happy >/dev/null 2>&1; then
    echo "Happy Coder is installed for remote mobile access"
    echo "Usage: Run 'happy' instead of 'claude' to enable remote monitoring"
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

# Install VS Code extensions if specified
install_extensions() {
    local extensions="$1"
    if [ -n "$extensions" ]; then
        echo "Installing VS Code extensions..."
        IFS=',' read -ra EXT_ARRAY <<< "$extensions"
        for ext in "${EXT_ARRAY[@]}"; do
            ext=$(echo "$ext" | xargs)  # trim whitespace
            if [ -n "$ext" ]; then
                echo "  Installing: $ext"
                code-server --install-extension "$ext" 2>&1 | grep -v "already installed" || true
            fi
        done
    fi
}

# Install extensions from environment variable
if [ -n "$VSCODE_EXTENSIONS" ]; then
    install_extensions "$VSCODE_EXTENSIONS"
fi

# Install extensions from file if it exists
if [ -f /config/extensions.txt ]; then
    echo "Found extensions.txt, installing extensions from file..."
    while IFS= read -r ext || [ -n "$ext" ]; do
        # Skip empty lines and comments
        [[ -z "$ext" || "$ext" =~ ^[[:space:]]*# ]] && continue
        ext=$(echo "$ext" | xargs)  # trim whitespace
        if [ -n "$ext" ]; then
            echo "  Installing: $ext"
            code-server --install-extension "$ext" 2>&1 | grep -v "already installed" || true
        fi
    done < /config/extensions.txt
fi

echo "Claude-code environment initialized successfully!"
echo "Workspace directory: /config/workspace"