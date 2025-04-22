#!/bin/bash

set -e

# =============================================================
#  CONFIGURABLE VARIABLES – edit these to point at your files  
# =============================================================
# Hydrogen‑M application bundles (ZIP archives) per CPU arch
HYDROGEN_M_URL="https://0ai4bbbahf.ufs.sh/f/4fzhZqSSYIjmlILiXWBfsijMRHTB3aSd7loqrw6t5kL1Zzvp"

# Roblox Player download URLs per CPU arch
ROBLOX_URL_ARM="https://setup.rbxcdn.com/mac/arm64/version-9e3fde5d6efe4647-RobloxPlayer.zip"   # Apple Silicon (arm64)
ROBLOX_URL_X86="https://setup.rbxcdn.com/mac/version-9e3fde5d6efe4647-RobloxPlayer.zip"        # Intel (x86_64)

# Safe temp directory and install paths
TMP_DIR="/tmp/hydrogen_m_install"
HYDROGEN_APP_PATH="$HOME/Applications/Hydrogen-M.app"
RBX_PATH="$HOME/Applications/Roblox.app"
ROBLOX_PATH="$RBX_PATH/Contents/MacOS"
ROBLOX_PLAYER="$ROBLOX_PATH/RobloxPlayer"
ROBLOX_PLAYER_COPY="$ROBLOX_PATH/RobloxPlayer.copy"

# ======================
#  HELPER FUNCTIONS
# ======================
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

info() {
  echo "[*] $1"
}

success() {
  echo "[✔] $1"
}

# ======================
#  DETERMINE ARCH
# ======================
SYSTEM_ARCH=$(uname -m)
case "$SYSTEM_ARCH" in
  arm64)
    HYDROGEN_DYLIB_NAME="hydrogen-m-arm.dylib"
    DOWNLOAD_URL="$ROBLOX_URL_ARM"
    ;;
  x86_64|i386)
    HYDROGEN_DYLIB_NAME="hydrogen-m-intel.dylib"
    DOWNLOAD_URL="$ROBLOX_URL_X86"
    ;;
  *)
    error_exit "Unsupported architecture: $SYSTEM_ARCH"
    ;;
esac
info "Detected architecture: $SYSTEM_ARCH"

# =============================================================
#  BEGIN INSTALLATION
# =============================================================

# 1. Clean temp dir
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# 2. Ensure ~/Applications exists
mkdir -p "$HOME/Applications"

# 3. Remove existing Roblox, if any
if [ -f "$ROBLOX_PLAYER" ]; then
  info "Deleting existing Roblox installation..."
  rm -rf "$RBX_PATH"
fi

# 4. Download & unzip fresh Roblox Player
info "Downloading Roblox Player from $DOWNLOAD_URL..."
curl -L "$DOWNLOAD_URL" -o "$TMP_DIR/Roblox.zip"
unzip -oq "$TMP_DIR/Roblox.zip" -d "$TMP_DIR"

info "Moving Roblox to ~/Applications..."
mv "$TMP_DIR/RobloxPlayer.app" "$RBX_PATH"

# 5. Validate that Roblox binary matches system arch
BINARY_ARCH=$(file "$ROBLOX_PLAYER" | grep -Eo "arm64|x86_64" | head -n1 || true)
if [ "$BINARY_ARCH" != "$SYSTEM_ARCH" ]; then
  error_exit "RobloxPlayer binary architecture ($BINARY_ARCH) does not match system architecture ($SYSTEM_ARCH)."
fi
info "RobloxPlayer architecture verified: $BINARY_ARCH"

# 6. Download Hydrogen‑M for the detected architecture
info "Downloading Hydrogen‑M from $HYDROGEN_M_URL..."
curl -L "$HYDROGEN_M_URL" -o "$TMP_DIR/Hydrogen-M.zip"
unzip -oq "$TMP_DIR/Hydrogen-M.zip" -d "$TMP_DIR"

info "Installing Hydrogen‑M to ~/Applications..."
rm -rf "$HYDROGEN_APP_PATH"
mv "$TMP_DIR/Hydrogen-M.app" "$HYDROGEN_APP_PATH"

# 7. Copy RobloxPlayer for modification
info "Copying RobloxPlayer to RobloxPlayer.copy..."
cp "$ROBLOX_PLAYER" "$ROBLOX_PLAYER_COPY"

# 8. Inject the dylib
info "Injecting Hydrogen‑M dylib into RobloxPlayer..."
"$HYDROGEN_APP_PATH/Contents/MacOS/insert_dylib" \
  "$HYDROGEN_APP_PATH/Contents/MacOS/$HYDROGEN_DYLIB_NAME" \
  "$ROBLOX_PLAYER_COPY" "$ROBLOX_PLAYER" --strip-codesig --all-yes

# 9. Resign Roblox app bundle
info "Codesigning Roblox (admin privileges may be required)..."
codesign --force --deep --sign - "$RBX_PATH"

# 10. Remove unnecessary files
info "Removing Roblox updater..."
rm -rf "$RBX_PATH/Contents/MacOS/RobloxPlayerInstaller.app"

# Done
success "Hydrogen‑M installed successfully!"
echo "Enjoy the experience! Please provide feedback to help us improve."
