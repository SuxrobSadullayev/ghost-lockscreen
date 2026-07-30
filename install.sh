#!/bin/bash

# ============================================================
# install.sh - lockscreen tool installer
# Run this on School21 computers to install the tool
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/bin"
TOOL_NAME="lockscreen"

echo "=== lockscreen installer ==="
echo ""

# Create ~/.local/bin if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    echo "Created directory: $INSTALL_DIR"
fi

# Copy the script
cp "$SCRIPT_DIR/$TOOL_NAME" "$INSTALL_DIR/$TOOL_NAME"
chmod +x "$INSTALL_DIR/$TOOL_NAME"
echo "✓ Installed: $INSTALL_DIR/$TOOL_NAME"

# Check if ~/.local/bin is in PATH
if echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo "✓ $INSTALL_DIR is already in PATH"
else
    echo ""
    echo "⚠ Adding $INSTALL_DIR to PATH..."

    # Detect shell config file
    if [ -f "$HOME/.zshrc" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        SHELL_RC="$HOME/.bashrc"
    else
        SHELL_RC="$HOME/.profile"
    fi

    echo '' >> "$SHELL_RC"
    echo '# lockscreen tool' >> "$SHELL_RC"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"

    echo "✓ Added PATH to $SHELL_RC"
    echo ""
    echo "  Run this to apply now:"
    echo "    source $SHELL_RC"
fi

echo ""
echo "=== Installation complete! ==="
echo ""
echo "Usage:"
echo "  lockscreen 6h       - disable auto-lock for 6 hours"
echo "  lockscreen 90m      - disable auto-lock for 90 minutes"
echo "  lockscreen off      - immediately restore auto-lock"
echo "  lockscreen status   - show current status"
echo ""
