# ai.claude.desktop

An **unofficial** Flatpak repackage of [Claude Desktop for Linux](https://code.claude.com/docs/en/desktop-linux)
(currently in beta). Anthropic ships the app only as a `.deb`; this manifest
downloads that official, signed package onto your own machine at *install*
time (an `extra-data` source) and runs it inside a Flatpak sandbox via
[zypak](https://github.com/refi64/zypak). No Anthropic code or binaries are
redistributed in this repository — only packaging metadata.

Claude Code (the integrated terminal/editor/diff-review tab) runs commands on
the **host**, not inside the sandbox, via a small Go relay
([host-spawn](https://github.com/1player/host-spawn)) that talks to the
`org.freedesktop.Flatpak` portal. That's what lets it see your real `git`,
`node`, `python`, and project tools instead of the empty runtime.

Supports `x86_64` and `aarch64`.

## Quick Start

This repo only ever contains `ai.claude.desktop` itself - the `org.freedesktop.Platform`
runtime and `org.electronjs.Electron2.BaseApp` it's built on come from Flathub, same as
for any third-party single-app repo. `flatpak` resolves those automatically from
*any* remote already configured **in the same installation scope**, so make sure
Flathub and this remote are both `--user` or both system-wide - not one of each,
or you'll hit `requires the runtime ... which was not found` even though Flathub
is right there. `--user` (no `sudo`) is the simpler default:

```bash
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --user --if-not-exists francoism90-claude-desktop https://francoism90.github.io/ai.claude.desktop/index.flatpakrepo
```

Update and install:

```bash
flatpak update
flatpak install francoism90-claude-desktop ai.claude.desktop
```

> Note: the app will automatically update when you run `flatpak update`.

```bash
flatpak run ai.claude.desktop
```

### Build

It is possible to build the app yourself instead of using the prebuilt,
signed repo above.

```sh
git clone https://github.com/francoism90/ai.claude.desktop.git
cd ai.claude.desktop
./build.sh
flatpak run ai.claude.desktop
```

`build.sh` adds the Flathub remote (user), installs the `golang` SDK extension
needed to build `host-spawn`, builds to a local repo, then installs from that
repo with the host's own `flatpak` binary (see "Nested-sandbox install error"
below for why it's split into two steps).

To build manually:

```sh
cd src/ai.claude.desktop
flatpak-builder --user --install-deps-from=flathub --force-clean --repo=repo \
  build-dir ai.claude.desktop.yml
flatpak --user remote-add --if-not-exists ai.claude.desktop-local ./repo --no-gpg-verify
flatpak --user install --noninteractive ai.claude.desktop-local ai.claude.desktop
```

#### Nested-sandbox install error

If `flatpak-builder` on your `$PATH` is itself a Flatpak (`org.flatpak.Builder`,
e.g. on immutable/hardened distros without a native package), running it with
`--install` directly can fail with:

```
bwrap: No permissions to create a new namespace, likely because the kernel
does not allow non-privileged user namespaces.
Error: Failed to install ai.claude.desktop: ...
```

That's `org.flatpak.Builder`'s own sandbox trying to nest another `bwrap`
sandbox for `flatpak install`, which some kernels/hardening policies (this was
found on secureblue) block regardless of user-namespace permissions otherwise
being fine. Building to a local repo and installing with the *host's* `flatpak`
binary — as `build.sh` and the manual steps above do — sidesteps it, since that
install then only needs one level of sandboxing, not two.

## Credits

Built on top of two existing Claude Desktop Flatpak projects:

- [dewzor/ClaudeDesktop](https://github.com/dewzor/ClaudeDesktop)
  (`io.github.dewzor.ClaudeDesktop`) — the manifest shape used here: the
  `extra-data` fetch (Flathub-compatible, no proprietary redistribution),
  `finish-args`, `.desktop`/metainfo/icon handling, and the `host-spawn` /
  `host-shell` / `host-exec` / `host-git` relay that lets Claude Code reach the
  host's real toolchain. It in turn credits
  [gordonmessmer/com.anthropic.Claude](https://github.com/gordonmessmer/com.anthropic.Claude)
  for the original finish-args/launcher shape.
- [jennifgcrl/claude-desktop-flatpak](https://github.com/jennifgcrl/claude-desktop-flatpak)
  (`me.jezh.ClaudeDesktop`) — pinning the `.deb` straight from Anthropic's own
  apt repo (`downloads.claude.ai/claude-desktop/apt/stable`, the basis for this
  manifest's `x-checker-data: debian-repo` updater) and the Cowork/QEMU/OVMF
  module referenced under "What works / what doesn't" below.

Repository layout and CI (Flatter signed builds, the daily update checker,
`bin/create-keys`) are modeled on my own
[org.freedesktop.Sdk.Extension.podman](https://github.com/francoism90/org.freedesktop.Sdk.Extension.podman).

## Repository layout

- `src/ai.claude.desktop/` — the manifest, launcher scripts, desktop entry,
  AppStream metainfo, and icons. `flatpak-external-data-checker` and the
  update-checker workflow discover manifests by convention
  (`src/<name>/<name>.yml`).
- `.github/workflows/flatter.yml` — builds, GPG-signs, and publishes the
  signed repo used by "Quick Start" above to GitHub Pages using
  [Flatter](https://github.com/andyholmes/flatter). Runs on push and weekly.
- `.github/workflows/update-checker.yml` — runs
  [flatpak-external-data-checker](https://github.com/flathub/flatpak-external-data-checker)
  daily against every discovered manifest and opens a PR when Anthropic
  publishes a new build (see "Updating" below).
- `bin/create-keys` — one-time helper to generate the GPG signing key used by
  `flatter.yml` and print the values to add as repo secrets.

## Updating

The pinned version and per-arch `sha256`/`size` live in
`src/ai.claude.desktop/ai.claude.desktop.yml`. Each `extra-data` source
carries `x-checker-data` of type `debian-repo`, pointed at Anthropic's own apt
repo (`downloads.claude.ai/claude-desktop/apt/stable`), so
`flatpak-external-data-checker` can detect new releases without scraping a
redirect endpoint. `update-checker.yml` runs it daily and opens a PR; merging
that PR (or pushing to `main` directly) triggers `flatter.yml`, which rebuilds
and republishes the repo above — no manual build step needed.

To check for updates locally instead:

```sh
docker run --rm -v "$PWD:/checker" -w /checker \
  ghcr.io/flathub/flatpak-external-data-checker:latest \
  --update src/ai.claude.desktop/ai.claude.desktop.yml
git diff
./build.sh
```

## What works / what doesn't

- **Chat, Claude Code** (integrated terminal, editor, diff review): work.
  Claude Code's shell commands and `git` run on the host via `host-spawn`
  (see `claude-desktop.sh`, `host-shell.sh`, `host-exec.sh`, `host-git.sh`).
- **Credentials, notifications, tray icon**: wired up via the Secret Service
  (`org.freedesktop.secrets`, KWallet), notification, and StatusNotifier
  D-Bus names in `finish-args`.
- **Cowork** (the sandboxed-VM feature): **not included by default.** The
  `.deb` bundles the VM image and `virtiofsd`, but not `qemu-system-x86_64`
  itself, and the app looks for UEFI firmware at a hardcoded `/usr/share/OVMF`
  path that doesn't exist in the read-only runtime. Building QEMU + OVMF from
  source and adding `--device=kvm` (or `--device=all`, for the KVM +
  `vhost-vsock` pair Cowork needs) makes it work — see
  [jennifgcrl/claude-desktop-flatpak](https://github.com/jennifgcrl/claude-desktop-flatpak)
  for a complete, working module for that.
- **Sandbox caveat for Claude Code:** the app itself runs inside the Flatpak
  sandbox, but its shell commands and `git` are relayed to the host, so they
  see your real toolchain (`--filesystem=home` covers project file access, and
  shares `~/.claude` with the CLI). Narrow that to specific project
  directories if you want tighter isolation.

## Permissions

See `finish-args` in the manifest — notably `--filesystem=home` (broad; needed
for Claude Code/Cowork to work with arbitrary project directories) and
`--talk-name=org.freedesktop.Flatpak` (lets `host-spawn` run commands on the
host — see "What works" above).

## How it works

1. `flatpak-builder` builds `host-spawn` from vendored Go sources and installs
   the launcher scripts, `.desktop` entry, icons and AppStream metadata — all
   at build time, without touching the proprietary payload.
2. At **install** time, Flatpak downloads the official per-arch `.deb`
   (checksum-pinned in the manifest) as an `extra-data` source, then runs
   `apply_extra`.
3. `apply_extra` unpacks the `.deb` (an `ar` archive containing a `data.tar.xz`)
   with `bsdtar`, drops the SUID `chrome-sandbox` (zypak replaces it), and
   patches the Electron app's desktop-filename via
   `patch-electron-desktop-filename` so the Wayland `app_id` matches this
   app's `.desktop` entry.
4. `claude-desktop.sh` launches the bundled Electron binary through
   `zypak-wrapper`, after probing the `org.freedesktop.Flatpak` portal and
   pointing `$SHELL` / `$CLAUDE_CODE_SHELL_PREFIX` at the `host-*` wrappers so
   Claude Code's terminal and agent commands run on the host.

## Disclaimer

Not affiliated with or endorsed by Anthropic. "Claude" and related marks
belong to Anthropic PBC. This repository only contains packaging metadata —
no Anthropic code or binaries are redistributed here; they are fetched from
Anthropic's own servers at install time.
