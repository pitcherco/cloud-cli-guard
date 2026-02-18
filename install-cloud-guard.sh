#!/bin/bash
# Cloud CLI Guard - Quick Setup Script
# Supports: Bash, Zsh, Fish
# Installs safety wrappers for Azure CLI (az) and GitHub CLI (gh)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD_SCRIPT="${GUARD_SCRIPT:-$SCRIPT_DIR/cloud-cli-guard.sh}"

echo "=================================="
echo "Cloud CLI Guard - Setup"
echo "=================================="
echo ""

# Detect shell
if [[ -n "$BASH_VERSION" ]]; then
    CURRENT_SHELL="bash"
    SHELL_CONFIG="$HOME/.bashrc"
elif [[ -n "$ZSH_VERSION" ]]; then
    CURRENT_SHELL="zsh"
    SHELL_CONFIG="$HOME/.zshrc"
elif [[ "$SHELL" == *"fish"* ]]; then
    CURRENT_SHELL="fish"
    SHELL_CONFIG="$HOME/.config/fish/config.fish"
else
    CURRENT_SHELL=$(basename "$SHELL")
    case "$CURRENT_SHELL" in
        bash) SHELL_CONFIG="$HOME/.bashrc" ;;
        zsh) SHELL_CONFIG="$HOME/.zshrc" ;;
        fish) SHELL_CONFIG="$HOME/.config/fish/config.fish" ;;
        *)
            echo "Unknown shell: $CURRENT_SHELL"
            echo "Please manually add the functions to your shell config"
            exit 1
            ;;
    esac
fi

echo "Detected shell: $CURRENT_SHELL"
echo "Config file: $SHELL_CONFIG"
echo ""

# Check if guard script exists
if [[ ! -f "$GUARD_SCRIPT" ]]; then
    echo "ERROR: Guard script not found at: $GUARD_SCRIPT"
    echo ""
    echo "Please ensure cloud-cli-guard.sh is in the same directory as this installer"
    echo "Or set GUARD_SCRIPT environment variable:"
    echo "  GUARD_SCRIPT=/path/to/cloud-cli-guard.sh ./install-cloud-guard.sh"
    exit 1
fi

# Create directories
echo "Creating directories..."
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.azure/approvals"
if [[ "$CURRENT_SHELL" == "fish" ]]; then
    mkdir -p "$HOME/.config/fish"
fi

# Copy the guard script
echo "Installing Cloud CLI Guard..."
cp "$GUARD_SCRIPT" "$HOME/.local/bin/cloud-cli-guard"
chmod +x "$HOME/.local/bin/cloud-cli-guard"
echo "✓ Guard script installed to ~/.local/bin/cloud-cli-guard"
echo ""

# Find real CLI locations
echo "Detecting CLI installations..."
AZ_PATH=""
GH_PATH=""

# Try to find Azure CLI
for path in /opt/homebrew/bin/az /usr/local/bin/az /usr/bin/az "$HOME/.local/bin/az"; do
    if [[ -x "$path" ]]; then
        AZ_PATH="$path"
        break
    fi
done

# Try to find GitHub CLI
for path in /opt/homebrew/bin/gh /usr/local/bin/gh /usr/bin/gh "$HOME/.local/bin/gh"; do
    if [[ -x "$path" ]]; then
        GH_PATH="$path"
        break
    fi
done

if [[ -z "$AZ_PATH" && -z "$GH_PATH" ]]; then
    echo "⚠️  WARNING: Neither Azure CLI (az) nor GitHub CLI (gh) found"
    echo "   Please install them first, then update paths in ~/.local/bin/cloud-cli-guard"
elif [[ -z "$AZ_PATH" ]]; then
    echo "⚠️  WARNING: Azure CLI (az) not found"
    echo "   GitHub CLI found at: $GH_PATH"
    echo "   Please install Azure CLI or update REAL_AZ in ~/.local/bin/cloud-cli-guard"
elif [[ -z "$GH_PATH" ]]; then
    echo "⚠️  WARNING: GitHub CLI (gh) not found"  
    echo "   Azure CLI found at: $AZ_PATH"
    echo "   Please install GitHub CLI or update REAL_GH in ~/.local/bin/cloud-cli-guard"
else
    echo "✓ Azure CLI found: $AZ_PATH"
    echo "✓ GitHub CLI found: $GH_PATH"
fi

# Update paths in the guard script
if [[ -n "$AZ_PATH" ]]; then
    sed -i.bak "s|REAL_AZ=.*|REAL_AZ=\"$AZ_PATH\"|" "$HOME/.local/bin/cloud-cli-guard" 2>/dev/null || \
    sed -i "s|REAL_AZ=.*|REAL_AZ=\"$AZ_PATH\"|" "$HOME/.local/bin/cloud-cli-guard"
fi

if [[ -n "$GH_PATH" ]]; then
    sed -i.bak "s|REAL_GH=.*|REAL_GH=\"$GH_PATH\"|" "$HOME/.local/bin/cloud-cli-guard" 2>/dev/null || \
    sed -i "s|REAL_GH=.*|REAL_GH=\"$GH_PATH\"|" "$HOME/.local/bin/cloud-cli-guard"
fi

# Remove backup files if created
rm -f "$HOME/.local/bin/cloud-cli-guard.bak"

echo "✓ Updated CLI paths in guard script"
echo ""

# Add shell functions
echo "Adding shell functions to $SHELL_CONFIG..."

# Check if already installed
if grep -q "cloud-cli-guard" "$SHELL_CONFIG" 2>/dev/null; then
    echo "⚠️  Guard functions already exist in $SHELL_CONFIG"
    echo "   Skipping installation (already configured)"
else
    if [[ "$CURRENT_SHELL" == "fish" ]]; then
        cat >> "$SHELL_CONFIG" << 'EOF'

# Cloud CLI Guard - Safety Wrappers
# Intercepts dangerous Azure and GitHub operations
function az
    env CLI_TYPE="az" ~/.local/bin/cloud-cli-guard $argv
end

function gh
    env CLI_TYPE="gh" ~/.local/bin/cloud-cli-guard $argv
end
EOF
    else
        cat >> "$SHELL_CONFIG" << 'EOF'

# Cloud CLI Guard - Safety Wrappers
# Intercepts dangerous Azure and GitHub operations
az() {
    CLI_TYPE="az" ~/.local/bin/cloud-cli-guard "$@"
}

gh() {
    CLI_TYPE="gh" ~/.local/bin/cloud-cli-guard "$@"
}
EOF
    fi
    echo "✓ Functions added to $SHELL_CONFIG"
fi

echo ""
echo "=================================="
echo "Setup Complete!"
echo "=================================="
echo ""
echo "Next steps:"
echo "1. Reload your shell configuration:"
echo "   source $SHELL_CONFIG"
echo ""
echo "2. Test the installation:"
echo "   az --guard-status"
echo "   gh --guard-status"
echo ""
echo "3. Try a blocked command:"
echo "   az group delete -n fake-resource-group"
echo "   gh repo delete fake-repo"
echo ""
echo "Files installed:"
echo "  ~/.local/bin/cloud-cli-guard (main script)"
echo "  ~/.azure/az-guard-config (configuration)"
echo "  ~/.azure/az-guard-audit.log (audit trail)"
echo ""
echo "Documentation:"
echo "  README.md - Quick start guide"
echo "  CLOUD_CLI_GUARD_SETUP.md - Complete documentation"
echo ""
echo "To uninstall:"
echo "  1. Remove the az() and gh() functions from $SHELL_CONFIG"
echo "  2. rm ~/.local/bin/cloud-cli-guard"
echo ""
