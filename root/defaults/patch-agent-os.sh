#!/usr/bin/env bash
# Patch Agent-OS for container compatibility

AGENT_OS_SERVER="/config/.agent-os/repo/server.ts"

if [ -f "$AGENT_OS_SERVER" ]; then
    echo "Patching Agent-OS for container environment..."

    # 1. Use bash instead of zsh (which doesn't exist in the container)
    sed -i 's|"/bin/zsh"|"/bin/bash"|g' "$AGENT_OS_SERVER"

    # 2. Use a more complete PATH that includes git and other tools
    # Replace the minimal PATH with one that includes all standard locations
    sed -i 's#PATH: process.env.PATH || "/usr/local/bin:/usr/bin:/bin"#PATH: process.env.PATH || "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/config/.npm-global/bin:/config/.local/bin"#g' "$AGENT_OS_SERVER"

    # 3. Set proper default HOME and USER for container environment
    # Default to /config (abc user's home) instead of root
    sed -i 's#HOME: process.env.HOME || "/"#HOME: process.env.HOME || "/config"#g' "$AGENT_OS_SERVER"
    sed -i 's#USER: process.env.USER || ""#USER: process.env.USER || "abc"#g' "$AGENT_OS_SERVER"
    sed -i 's#cwd: process.env.HOME || "/"#cwd: process.env.HOME || "/config"#g' "$AGENT_OS_SERVER"

    echo "✓ Agent-OS patched for container compatibility"
    echo "  - Shell set to /bin/bash"
    echo "  - PATH expanded to include git and other tools"
    echo "  - User set to abc (not root) for security"
    echo "  - Home directory set to /config"
else
    echo "Agent-OS server.ts not found, skipping patch"
fi