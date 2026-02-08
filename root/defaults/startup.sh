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

# Install Claude Code via native installer if not already present
# Native install puts binary at ~/.local/bin/claude with auto-updates
export PATH="$HOME/.local/bin:$PATH"
if [ ! -x "$HOME/.local/bin/claude" ]; then
    echo "Installing Claude Code via native installer..."
    curl -fsSL https://claude.ai/install.sh | bash 2>&1 | tail -20

    # Verify installation succeeded
    if [ -x "$HOME/.local/bin/claude" ]; then
        echo "✓ Claude Code installed successfully (native)"
    else
        echo "✗ Claude Code installation failed - check logs above"
    fi
fi

# Install Happy Coder to /config/.npm-global if not already present
if [ ! -x /config/.npm-global/bin/happy ]; then
    echo "Installing Happy Coder to /config/.npm-global..."
    npm install -g happy-coder 2>&1 | tail -20

    # Verify installation succeeded
    if [ -x /config/.npm-global/bin/happy ]; then
        echo "✓ Happy Coder installed successfully"
    else
        echo "✗ Happy Coder installation failed - check logs above"
    fi
fi

# Install OpenAI Codex if not already functional
if [ ! -x /config/.npm-global/bin/codex ]; then
    echo "Installing OpenAI Codex to /config/.npm-global for auto-updates..."
    npm install -g @openai/codex 2>&1 | tail -20

    # Verify installation succeeded
    if [ -x /config/.npm-global/bin/codex ]; then
        echo "✓ OpenAI Codex installed successfully"
    else
        echo "✗ OpenAI Codex installation failed - check logs above"
    fi
fi

# Claude Code UI is built from source at /opt/claude-code-ui during image build
# It runs as an s6 longrun service (svc-claude-code-ui) on port 3001

# Install Google Gemini CLI if not already functional
if [ ! -x /config/.npm-global/bin/gemini ]; then
    echo "Installing Google Gemini CLI to /config/.npm-global for auto-updates..."
    npm install -g @google/gemini-cli 2>&1 | tail -20

    # Verify installation succeeded
    if [ -x /config/.npm-global/bin/gemini ]; then
        echo "✓ Google Gemini CLI installed successfully"
    else
        echo "✗ Google Gemini CLI installation failed - check logs above"
    fi
fi

# Add ~/.local/bin and /config/.npm-global/bin to PATH permanently for all shells
if [ ! -f ~/.bashrc ] || ! grep -q '\.local/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi
if [ ! -f ~/.bashrc ] || ! grep -q "/config/.npm-global/bin" ~/.bashrc; then
    echo 'export PATH="/config/.npm-global/bin:$PATH"' >> ~/.bashrc
fi

# Configure BROWSER environment variable to use our container-friendly browser helper
# This allows OAuth flows from CLI tools to work in the containerized code-server environment
if [ ! -f ~/.bashrc ] || ! grep -q "BROWSER=" ~/.bashrc; then
    echo 'export BROWSER="/usr/local/bin/browser-helper"' >> ~/.bashrc
fi
export BROWSER="/usr/local/bin/browser-helper"

# Note: Claude Code native installer manages its own auto-updates
# No config.json needed - native installs update automatically in the background

# Clean up old tmux terminal profile from settings.json (from previous image versions)
MACHINE_SETTINGS="/config/data/Machine/settings.json"
if [ -f "$MACHINE_SETTINGS" ] && grep -q '"terminal.integrated.defaultProfile.linux".*tmux' "$MACHINE_SETTINGS" 2>/dev/null; then
    echo "Removing old tmux terminal profile from code-server settings..."
    jq 'del(."terminal.integrated.defaultProfile.linux") | del(."terminal.integrated.profiles.linux".tmux) | if ."terminal.integrated.profiles.linux" == {} then del(."terminal.integrated.profiles.linux") else . end' \
        "$MACHINE_SETTINGS" > "${MACHINE_SETTINGS}.tmp" && mv "${MACHINE_SETTINGS}.tmp" "$MACHINE_SETTINGS"
fi

# Clean up old tmux auto-start from .bashrc (from previous image versions)
if [ -f ~/.bashrc ] && grep -q 'exec tmux' ~/.bashrc; then
    echo "Removing old tmux auto-start from .bashrc..."
    sed -i '/# Auto-start tmux for interactive terminal sessions/,/^fi$/d' ~/.bashrc
    # Also remove any leftover blank lines from the removal
    sed -i '/^$/N;/^\n$/d' ~/.bashrc
fi

# Check if claude-code is available
if command -v claude >/dev/null 2>&1; then
    echo "Claude Code CLI is installed and ready"
    echo "To authenticate, run: claude setup-token"
else
    echo "Warning: Claude Code CLI not found"
fi

# Check if codex is available
if command -v codex >/dev/null 2>&1; then
    echo "OpenAI Codex CLI is installed and ready"
    echo "To authenticate:"
    echo "  - Option 1: Sign in with ChatGPT (Plus/Pro/Team) - run: codex"
    echo "  - Option 2: Use API key - set OPENAI_API_KEY environment variable"
else
    echo "Warning: OpenAI Codex CLI not found"
fi

# Check if happy-coder is available
if command -v happy >/dev/null 2>&1; then
    echo "Happy Coder is installed for remote mobile access"
    echo "Usage: Run 'happy' instead of 'claude' to enable remote monitoring"
fi

# Check if gemini is available
if command -v gemini >/dev/null 2>&1; then
    echo "Google Gemini CLI is installed and ready"
    echo "To authenticate:"
    echo "  - Option 1: Sign in with Google account - run: gemini"
    echo "  - Option 2: Use API key - set GOOGLE_API_KEY environment variable"
else
    echo "Warning: Google Gemini CLI not found"
fi

# Check if Claude Code UI is available
if [ -f /opt/claude-code-ui/server/index.js ]; then
    CCUI_VERSION=$(node -e "console.log(require('/opt/claude-code-ui/package.json').version)" 2>/dev/null)
    echo "Claude Code UI v${CCUI_VERSION} is built-in (runs as s6 service on port 3001)"
fi

# Check if OpenAI Python package is available
if python3 -c "import openai" 2>/dev/null; then
    echo "OpenAI Python package is installed and ready"
    echo "To use: Set OPENAI_API_KEY environment variable or run 'openai auth login'"
    # Show current OpenAI package version
    OPENAI_VERSION=$(python3 -c "import openai; print(openai.__version__)" 2>/dev/null)
    if [ -n "$OPENAI_VERSION" ]; then
        echo "OpenAI version: $OPENAI_VERSION"
    fi
else
    echo "Warning: OpenAI Python package not found"
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

# Browser helper status
echo "Browser helper configured for OAuth flows in containerized environment"
echo "CLI tools will display clickable links in code-server's terminal"

# code-server binary path (LinuxServer.io base image location)
# Export so sourced scripts (like install-copilot.sh) inherit this
export CODE_SERVER_BIN="${CODE_SERVER_BIN:-/app/code-server/bin/code-server}"

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
                "$CODE_SERVER_BIN" --install-extension "$ext" 2>&1 | grep -v "already installed" || true
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
            "$CODE_SERVER_BIN" --install-extension "$ext" 2>&1 | grep -v "already installed" || true
        fi
    done < /config/extensions.txt
fi

# Install GitHub Copilot extensions (not available in Open VSX)
# These are installed from VS Code Marketplace using a custom script
if [ -f /defaults/install-copilot.sh ]; then
    echo ""
    echo "Installing GitHub Copilot extensions..."
    # Source the script to get the function, then call it
    source /defaults/install-copilot.sh
    install_copilot_extensions || echo "Warning: GitHub Copilot installation had issues (may still work)"
fi

echo "Claude-code environment initialized successfully!"
echo "Workspace directory: /config/workspace"