#!/usr/bin/env bash

# GitHub Copilot Extensions Installer for code-server
# These extensions aren't available in Open VSX, so we install from VS Code Marketplace

# code-server binary path (LinuxServer.io base image location)
CODE_SERVER_BIN="${CODE_SERVER_BIN:-/app/code-server/bin/code-server}"

# Extract VS Code version from code-server
get_vscode_version() {
    # code-server outputs: "4.108.2 <hash> with Code 1.108.2"
    # We need the VS Code version (after "with Code ")
    "$CODE_SERVER_BIN" --version | head -n1 | sed -n 's/.*with Code \([0-9.]*\).*/\1/p'
}

# Get user-data-dir from running code-server process
get_user_data_dir() {
    local process_info
    if command -v ps >/dev/null 2>&1; then
        process_info=$(ps aux 2>/dev/null | grep -v grep | grep "code-server" | head -n 1) ||
        process_info=$(ps -ef 2>/dev/null | grep -v grep | grep "code-server" | head -n 1)
    fi

    if [ -n "$process_info" ]; then
        echo "$process_info" | grep -o -- '--user-data-dir=[^ ]*' | sed 's/--user-data-dir=//'
    fi
}

# Find compatible extension version
find_compatible_version() {
    local extension_id="$1"
    local vscode_version="$2"

    local response
    response=$(curl -s -X POST "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json;api-version=3.0-preview.1" \
        -d "{
            \"filters\": [{
                \"criteria\": [
                    {\"filterType\": 7, \"value\": \"$extension_id\"},
                    {\"filterType\": 12, \"value\": \"4096\"}
                ],
                \"pageSize\": 50
            }],
            \"flags\": 4112
        }")

    echo "$response" | jq -r --arg vscode_version "$vscode_version" '
        .results[0].extensions[0].versions[] |
        select(.version | test("^[0-9]+\\.[0-9]+\\.[0-9]*$")) |
        select(.version | length < 8) |
        {
            version: .version,
            engine: (.properties[] | select(.key == "Microsoft.VisualStudio.Code.Engine") | .value)
        } |
        select(.engine | ltrimstr("^") | split(".") |
            map(split("-")[0] | tonumber?) as $engine_parts |
            ($vscode_version | split(".") | map(tonumber)) as $vscode_parts |
            (
                ($engine_parts[0] // 0) < $vscode_parts[0] or
                (($engine_parts[0] // 0) == $vscode_parts[0] and ($engine_parts[1] // 0) < $vscode_parts[1]) or
                (($engine_parts[0] // 0) == $vscode_parts[0] and ($engine_parts[1] // 0) == $vscode_parts[1] and ($engine_parts[2] // 0) <= $vscode_parts[2])
            )
        ) |
        .version' | head -n 1
}

# Install extension
install_extension() {
    local extension_id="$1"
    local version="$2"
    local user_data_dir="$3"
    local extension_name
    extension_name=$(echo "$extension_id" | cut -d'.' -f2)
    local temp_dir="/tmp/code-extensions"

    echo "Installing $extension_id v$version..."

    mkdir -p "$temp_dir"

    echo "  Downloading..."
    curl -sL "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/GitHub/vsextensions/$extension_name/$version/vspackage" \
        -o "$temp_dir/$extension_name.vsix.gz"

    if [ ! -f "$temp_dir/$extension_name.vsix.gz" ]; then
        echo "  ✗ Download failed for $extension_id"
        return 1
    fi

    # Decompress
    if command -v gunzip >/dev/null 2>&1; then
        gunzip -f "$temp_dir/$extension_name.vsix.gz"
    else
        gzip -df "$temp_dir/$extension_name.vsix.gz"
    fi

    # Install with user-data-dir if provided
    if [ -n "$user_data_dir" ]; then
        "$CODE_SERVER_BIN" --user-data-dir="$user_data_dir" --force --install-extension "$temp_dir/$extension_name.vsix"
    else
        "$CODE_SERVER_BIN" --force --install-extension "$temp_dir/$extension_name.vsix"
    fi

    rm -f "$temp_dir/$extension_name.vsix"

    echo "  ✓ $extension_id installed successfully!"
    return 0
}

# Main installation function
install_copilot_extensions() {
    echo "GitHub Copilot Extensions Installer"
    echo "===================================="
    echo ""

    # Check for required dependencies
    for cmd in curl jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: Missing required dependency: $cmd"
            return 1
        fi
    done

    # Get VS Code version
    VSCODE_VERSION="$(get_vscode_version)"

    if [ -z "$VSCODE_VERSION" ]; then
        echo "Error: Could not extract VS Code version from code-server"
        return 1
    fi

    echo "Detected VS Code version: $VSCODE_VERSION"

    # Check for user-data-dir in running code-server
    USER_DATA_DIR="$(get_user_data_dir)"
    if [ -n "$USER_DATA_DIR" ]; then
        echo "Detected user-data-dir: $USER_DATA_DIR"
    fi
    echo ""

    # Extensions to install
    EXTENSIONS="GitHub.copilot GitHub.copilot-chat"
    FAILED=0

    for ext in $EXTENSIONS; do
        echo "Processing $ext..."

        # Find compatible version
        version="$(find_compatible_version "$ext" "$VSCODE_VERSION")"

        if [ -z "$version" ]; then
            echo "  ✗ No compatible version found for $ext"
            FAILED="$((FAILED + 1))"
        else
            echo "  Found compatible version: $version"
            if ! install_extension "$ext" "$version" "$USER_DATA_DIR"; then
                FAILED="$((FAILED + 1))"
            fi
        fi
        echo ""
    done

    # Clean up
    rm -rf /tmp/code-extensions

    echo "===================================="
    if [ $FAILED -eq 0 ]; then
        echo "✓ All extensions installed successfully!"
        return 0
    else
        echo "⚠ Completed with $FAILED error(s)"
        return 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_copilot_extensions
fi
