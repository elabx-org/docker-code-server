#!/usr/bin/env bash
# GitHub Copilot Extensions Installer for code-server
# These extensions aren't available in Open VSX, so we install from VS Code Marketplace
# Supports both fresh installs and updates to newer versions

set -e

# code-server binary path (LinuxServer.io base image location)
CODE_SERVER_BIN="${CODE_SERVER_BIN:-/app/code-server/bin/code-server}"

# Extract VS Code version from code-server
get_vscode_version() {
    # code-server --version outputs: "4.106.3 f128a7ac113916c9c29cf8d1361ab4b7f3bd9e75 with Code 1.106.3"
    # We need the VS Code version (after "with Code "), not the code-server version
    # Use grep to find the line with "with Code", then sed to extract just the version number
    "$CODE_SERVER_BIN" --version 2>/dev/null | grep 'with Code' | sed 's/.*with Code //' | head -n1
}

# Get installed version of an extension
get_installed_version() {
    local extension_id="$1"
    local ext_dir="/config/.local/share/code-server/extensions"

    # Extension directories are named like: github.copilot-1.234.0
    local ext_lower
    ext_lower=$(echo "$extension_id" | tr '[:upper:]' '[:lower:]')

    # Find the extension directory and extract version
    if [ -d "$ext_dir" ]; then
        local found_dir
        found_dir=$(find "$ext_dir" -maxdepth 1 -type d -iname "${ext_lower}-*" 2>/dev/null | head -n1)
        if [ -n "$found_dir" ]; then
            # Extract version from directory name (e.g., github.copilot-1.234.0 -> 1.234.0)
            basename "$found_dir" | sed "s/^${ext_lower}-//"
        fi
    fi
}

# Compare semantic versions: returns 0 if $1 > $2, 1 otherwise
version_greater_than() {
    local ver1="$1"
    local ver2="$2"

    # Split versions into parts
    local IFS='.'
    read -ra v1_parts <<< "$ver1"
    read -ra v2_parts <<< "$ver2"

    # Compare each part
    for i in 0 1 2; do
        local p1="${v1_parts[$i]:-0}"
        local p2="${v2_parts[$i]:-0}"

        if [ "$p1" -gt "$p2" ] 2>/dev/null; then
            return 0
        elif [ "$p1" -lt "$p2" ] 2>/dev/null; then
            return 1
        fi
    done

    # Versions are equal
    return 1
}

# Find compatible extension version from VS Code Marketplace
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

# Install extension from VS Code Marketplace
install_extension() {
    local extension_id="$1"
    local version="$2"
    local action="${3:-Installing}"  # "Installing" or "Updating"
    local extension_name
    extension_name=$(echo "$extension_id" | cut -d'.' -f2)
    local temp_dir="/tmp/code-extensions"

    echo "$action $extension_id to v$version..."

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

    # Install extension (--force overwrites existing version)
    "$CODE_SERVER_BIN" --force --install-extension "$temp_dir/$extension_name.vsix"

    rm -f "$temp_dir/$extension_name.vsix"
    echo "  ✓ $extension_id v$version installed successfully!"
    return 0
}

# Main installation function
install_copilot_extensions() {
    echo "GitHub Copilot Extensions Installer"
    echo "===================================="

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
    echo "Detected VS Code engine version: $VSCODE_VERSION"
    echo ""

    # Extensions to install
    local extensions="GitHub.copilot GitHub.copilot-chat"
    local failed=0

    for ext in $extensions; do
        echo "Processing $ext..."

        # Get latest compatible version
        local latest_version
        latest_version="$(find_compatible_version "$ext" "$VSCODE_VERSION")"

        if [ -z "$latest_version" ]; then
            echo "  ✗ No compatible version found for $ext"
            failed=$((failed + 1))
            echo ""
            continue
        fi

        # Check installed version
        local installed_version
        installed_version="$(get_installed_version "$ext")"

        if [ -z "$installed_version" ]; then
            # Not installed - fresh install
            echo "  Latest compatible version: $latest_version"
            if ! install_extension "$ext" "$latest_version" "Installing"; then
                failed=$((failed + 1))
            fi
        elif [ "$installed_version" = "$latest_version" ]; then
            # Already at latest version
            echo "  ✓ Already at latest version ($installed_version)"
        elif version_greater_than "$latest_version" "$installed_version"; then
            # Update available
            echo "  Update available: $installed_version → $latest_version"
            if ! install_extension "$ext" "$latest_version" "Updating"; then
                failed=$((failed + 1))
            fi
        else
            # Installed version is newer or equal (edge case)
            echo "  ✓ Current version ($installed_version) is up to date"
        fi
        echo ""
    done

    # Clean up
    rm -rf /tmp/code-extensions

    echo "===================================="
    if [ $failed -eq 0 ]; then
        echo "✓ GitHub Copilot extensions are up to date!"
        return 0
    else
        echo "⚠ Completed with $failed error(s)"
        return 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_copilot_extensions
fi
