#!/usr/bin/env bash
# Build and install the Claude Desktop Flatpak (user install).
set -euo pipefail
cd "$(dirname "$0")/src/ai.claude.desktop"

MANIFEST="ai.claude.desktop.yml"
APP_ID="ai.claude.desktop"

# The runtime, SDK and Electron BaseApp come from Flathub. --install-deps-from
# reads their exact versions from the manifest, so they can never drift from it.
flatpak --user remote-add --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo

# The golang SDK extension (used to build host-spawn) also comes from Flathub.
flatpak --user install --noninteractive flathub org.freedesktop.Sdk.Extension.golang//25.08

if command -v flatpak-builder >/dev/null 2>&1; then
  fb() { flatpak-builder "$@"; }
elif flatpak info --user org.flatpak.Builder >/dev/null 2>&1 || flatpak info org.flatpak.Builder >/dev/null 2>&1; then
  fb() { flatpak run org.flatpak.Builder "$@"; }
else
  echo "Installing org.flatpak.Builder from Flathub..."
  flatpak --user install --noninteractive flathub org.flatpak.Builder
  fb() { flatpak run org.flatpak.Builder "$@"; }
fi

# Build to a local repo rather than installing directly with `fb --install`.
# On hosts that restrict nested user namespaces (e.g. hardened/atomic distros),
# org.flatpak.Builder — itself a sandboxed Flatpak app — cannot spawn the bwrap
# instance that `flatpak install` needs, and fails with "bwrap: No permissions
# to create a new namespace". Installing separately with the host's own
# `flatpak` binary avoids that nesting and works everywhere.
fb --user --install-deps-from=flathub --force-clean --repo=repo build-dir "$MANIFEST"

flatpak --user remote-add --if-not-exists "${APP_ID}-local" ./repo --no-gpg-verify
flatpak --user install --noninteractive "${APP_ID}-local" "$APP_ID"

echo
echo "Installed. Launch with:  flatpak run $APP_ID"
