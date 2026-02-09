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

    # 4. Make terminals spawn login shells to load .bashrc and get full environment
    # This ensures Claude Code and other tools use their global configs
    # Change spawn(shell, []) to spawn(shell, ["-l"])
    sed -i 's#ptyProcess = pty.spawn(shell, \[\], {#ptyProcess = pty.spawn(shell, ["-l"], {#g' "$AGENT_OS_SERVER"

    # 5. Add grace period before killing PTY on WebSocket disconnect
    # Without this, brief network interruptions instantly kill running Claude Code sessions
    # Replace immediate ptyProcess.kill() with a 5-minute delayed kill
    # The try/catch handles the case where the PTY already exited naturally
    sed -i 's#ptyProcess.kill();#setTimeout(() => { try { ptyProcess.kill(); } catch(e) {} }, 300000);#g' "$AGENT_OS_SERVER"

    echo "✓ Agent-OS server.ts patched for container compatibility"
    echo "  - Shell set to /bin/bash"
    echo "  - PATH expanded to include git and other tools"
    echo "  - User set to abc (not root) for security"
    echo "  - Home directory set to /config"
    echo "  - Terminals spawn as login shells (loads .bashrc)"
    echo "  - PTY processes get 5-min grace period on WebSocket disconnect"
else
    echo "Agent-OS server.ts not found, skipping patch"
fi

# Patches below modify source files and require a Next.js rebuild
NEEDS_REBUILD=false

# 6. Fix session PATCH API to handle projectId (move session to project)
# The PATCH /api/sessions/[id] route handles name, status, workingDirectory,
# systemPrompt, groupPath but is missing projectId handling. The frontend sends
# projectId when moving a session to a project, but the backend silently ignores it.
AGENT_OS_SESSION_ROUTE="/config/.agent-os/repo/app/api/sessions/[id]/route.ts"

if [ -f "$AGENT_OS_SESSION_ROUTE" ] && ! grep -q 'body.projectId' "$AGENT_OS_SESSION_ROUTE" 2>/dev/null; then
    # Insert projectId handling right before the "if (updates.length > 0)" line
    sed -i '/if (updates\.length > 0) {/i\    if (body.projectId !== undefined) {\n      updates.push("project_id = ?");\n      values.push(body.projectId);\n    }\n' "$AGENT_OS_SESSION_ROUTE"
    echo "✓ Patched session PATCH route: added projectId handling"
    NEEDS_REBUILD=true
fi

# 7. Fix Radix UI menu items: use onSelect instead of onClick
# Radix DropdownMenuItem/ContextMenuItem use onSelect as the canonical event handler.
# onClick can fail on mobile/touch because menu DOM is destroyed before click fires.
AGENT_OS_COMPONENTS="/config/.agent-os/repo/components"

if [ -d "$AGENT_OS_COMPONENTS" ]; then
    for COMPONENT_FILE in \
        "$AGENT_OS_COMPONENTS/Projects/ProjectCard.tsx" \
        "$AGENT_OS_COMPONENTS/SessionCard.tsx"; do
        if [ -f "$COMPONENT_FILE" ] && grep -q '<MenuItem onClick=' "$COMPONENT_FILE" 2>/dev/null; then
            sed -i 's#<MenuItem onClick=#<MenuItem onSelect=#g' "$COMPONENT_FILE"
            sed -i 's#<MenuItem\n\s*onClick=#<MenuItem\n              onSelect=#g' "$COMPONENT_FILE"
            echo "✓ Patched $(basename "$COMPONENT_FILE"): onClick → onSelect on menu items"
            NEEDS_REBUILD=true
        fi
    done
else
    echo "Agent-OS components directory not found, skipping UI patch"
fi

# Rebuild Next.js if any source patches were applied
if [ "$NEEDS_REBUILD" = true ]; then
    echo "Rebuilding Agent-OS frontend..."
    cd /config/.agent-os/repo && npm run build 2>&1 | tail -5
    echo "✓ Agent-OS frontend rebuilt"
fi
