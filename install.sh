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

# Other install locations (normally you can leave these alone)
TMP_DIR="/tmp/hydrogen_m_install"
HYDROGEN_APP_PATH="~/Applications/Hydrogen-M.app"
RBX_PATH="~/Applications/Roblox.app"
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

# 2. Remove existing Roblox, if any
if [ -f "$ROBLOX_PLAYER" ]; then
  info "Deleting existing Roblox installation..."
   rm -rf "$RBX_PATH"
fi

# 3. Download & unzip fresh Roblox Player
info "Downloading Roblox Player from $DOWNLOAD_URL..."
curl -L "$DOWNLOAD_URL" -o "$TMP_DIR/Roblox.zip"
unzip -oq "$TMP_DIR/Roblox.zip" -d "$TMP_DIR"

info "Moving Roblox to /Applications..."
mv "$TMP_DIR/RobloxPlayer.app" "$RBX_PATH"

# 4. Validate that Roblox binary matches system arch
BINARY_ARCH=$(file "$ROBLOX_PLAYER" | grep -Eo "arm64|x86_64" | head -n1 || true)
if [ "$BINARY_ARCH" != "$SYSTEM_ARCH" ]; then
  error_exit "RobloxPlayer binary architecture ($BINARY_ARCH) does not match system architecture ($SYSTEM_ARCH)."
fi
info "RobloxPlayer architecture verified: $BINARY_ARCH"

# 5. Download Hydrogen‑M for the detected architecture
info "Downloading Hydrogen‑M from $HYDROGEN_M_URL..."
curl -L "$HYDROGEN_M_URL" -o "$TMP_DIR/Hydrogen-M.zip"
unzip -oq "$TMP_DIR/Hydrogen-M.zip" -d "$TMP_DIR"

info "Installing Hydrogen‑M to /Applications..."
sudo rm -rf "$HYDROGEN_APP_PATH"
mv "$TMP_DIR/Hydrogen-M.app" "$HYDROGEN_APP_PATH"

# 6. Copy RobloxPlayer for modification
info "Copying RobloxPlayer to RobloxPlayer.copy..."
cp "$ROBLOX_PLAYER" "$ROBLOX_PLAYER_COPY"

# 7. Inject the dylib
info "Injecting Hydrogen‑M dylib into RobloxPlayer..."
"$HYDROGEN_APP_PATH/Contents/MacOS/insert_dylib" \
  "$HYDROGEN_APP_PATH/Contents/MacOS/$HYDROGEN_DYLIB_NAME" \
  "$ROBLOX_PLAYER_COPY" "$ROBLOX_PLAYER" --strip-codesig --all-yes

# 8. Resign Roblox app bundle
info "Codesigning Roblox (admin privileges required)..."
sudo codesign --force --deep --sign - "/Applications/Roblox.app"

# 9. Clean up unneeded Roblox bits and caches
info "Removing Roblox updater..."
rm -rf "/Applications/Roblox.app/Contents/MacOS/RobloxPlayerInstaller.app"

#info "Clearing Roblox cache files..."
#rm -f ~/Library/Preferences/com.roblox.*.plist || true
#defaults delete com.roblox.RobloxPlayer       2>/dev/null || true
#defaults delete com.roblox.RobloxStudio       2>/dev/null || true
#defaults delete com.roblox.Retention          2>/dev/null || true
#defaults delete com.roblox.RobloxStudioChannel 2>/dev/null || true
#defaults delete com.roblox.RobloxPlayerChannel 2>/dev/null || true
#killall cfprefsd 2>/dev/null || true

# 10. Finish
success "Hydrogen‑M installed successfully!"
echo "Enjoy the experience! Please provide feedback to help us improve."
