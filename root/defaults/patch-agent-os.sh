#!/usr/bin/env bash
# Patch Agent-OS to use bash instead of zsh (which doesn't exist in the container)

AGENT_OS_SERVER="/config/.agent-os/repo/server.ts"

if [ -f "$AGENT_OS_SERVER" ]; then
    echo "Patching Agent-OS to use /bin/bash instead of /bin/zsh..."
    sed -i 's|"/bin/zsh"|"/bin/bash"|g' "$AGENT_OS_SERVER"
    echo "✓ Agent-OS patched to use bash"
else
    echo "Agent-OS server.ts not found, skipping patch"
fi