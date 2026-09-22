# nixify — one Nix flake that configures all of my Linux machines

## What I want to build

A single Git repository containing a Nix flake that declaratively defines the complete
configuration of every Linux computer I own, and that can be applied to any of them with
one command. It replaces per-machine manual setup with a shared, version-controlled,
reproducible definition.

There are two kinds of machines and the flake must support both:

1. **NixOS hosts.** The flake defines the whole system (packages, services, users, system
   settings) plus my user environment. Applied with `nixos-rebuild switch --flake .#<host>`.
2. **Non-NixOS hosts** (e.g. Pop!_OS 22.04, Ubuntu, Debian) where Nix is installed on top
   of the existing distro. Only my user environment is managed, via standalone Home
   Manager. Applied with `home-manager switch --flake .#<user>@<host>`. System packages on
   these machines stay with the distro's package manager.

The same user-level configuration (editors, shell tools, dotfiles, credentials) must
produce an identical experience on both kinds of hosts.

## Who uses it

Only me. Single user, single maintainer, same Unix username on every machine. Optimize for
one person maintaining this for years, not for a team.

## Layering model

Configuration is composed in layers, lowest to highest precedence:

- **Base** — applies to every machine: a fixed set of tools, their config files, shell
  setup, and credentials.
- **Roles** (optional) — reusable bundles a host can opt into, e.g. `desktop`, `server`,
  `dev-cpp`, `dev-python`.
- **Host** — one directory per machine: hostname, hardware config (NixOS only),
  host-specific packages, services, and overrides of anything from the lower layers.

Adding a new machine must mean: create one host directory, add one entry to the flake
outputs, run the bootstrap. Nothing in the base layer should need editing.

## Required base tools (every machine)

- **git** with my identity, aliases, and a global gitignore managed declaratively.
- **tmux** with my configuration.
- **Vim** (Vim proper, not Neovim, unless a clear reason to switch surfaces) in two
  flavors that can be installed side by side on the same machine without sharing or
  clobbering plugin state:
  - **`vim-cpp`** — C++ development: LSP via clangd, code formatting (clang-format),
    integrated debugging with gdb (breakpoints, stepping, variable inspection inside
    Vim), and cmake/compiler toolchain available on PATH.
  - **`vim-py`** — Python development: LSP (pyright or python-lsp-server), formatting and
    linting (ruff), integrated debugging with debugpy (breakpoints, stepping, variable
    inspection inside Vim).
  - Both flavors share one common vimrc core (keymaps, appearance, general editing) and
    add language-specific plugins on top. All plugins are pinned through Nix, none
    fetched at runtime by a plugin manager.
  - A plain `vim` with only the common core must also remain available.

## Secrets and credentials

Credentials (SSH keys, API tokens, git credentials, etc.) live in the repository in
encrypted form and are decrypted only on the target machine at activation time. Plaintext
secrets never appear in the repo or in the world-readable Nix store. Preferred tool:
sops-nix with age keys, one age key per host. Must work for both NixOS and standalone
Home Manager hosts.

## Bootstrap of a fresh machine

Documented and, where possible, scripted:

- **Non-NixOS:** install Nix (multi-user, flakes enabled), clone the repo, provision the
  host's age key, run one command to apply the user configuration.
- **NixOS:** from the installer, clone the repo, generate hardware config into the host
  directory, provision the age key, run one command to install/switch.

Target: a fresh machine reaches the fully configured state in well under an hour of
wall-clock time with fewer than ten manual steps.

## Repository shape (proposal, adjust if there is a better idiom)

```
flake.nix / flake.lock
hosts/<hostname>/          # per-host config; hardware-configuration.nix for NixOS hosts
modules/nixos/             # shared NixOS modules
modules/home/              # shared Home Manager modules (git, tmux, vim, shell, ...)
roles/                     # optional opt-in bundles
users/<username>/          # user identity and user-level entry points
pkgs/                      # custom derivations, incl. the two vim flavors
secrets/                   # sops-encrypted files + .sops.yaml
scripts/                   # bootstrap helpers
docs/                      # how to add a host, rotate a key, etc.
```

## Technical constraints

- Nix flakes with pure evaluation. No channels, no `nix-env`, no imperative state.
- One `nixpkgs` input shared by all hosts (pinned via `flake.lock`); Home Manager as a
  flake input that follows that nixpkgs. Home Manager is used as a NixOS module on NixOS
  hosts and standalone elsewhere, from the same shared `modules/home` code.
- Primary architecture `x86_64-linux`; keep `aarch64-linux` possible without redesign.
- `nix flake check` must pass and must build every host's system closure and every
  standalone Home Manager configuration, so a broken host is caught from any machine
  before deploying.
- Nix code is formatted (nixfmt or alejandra) and the formatter is wired into
  `nix fmt` / `nix flake check`.
- Environment facts for the first host: Pop!_OS 22.04, `x86_64`, Nix 2.29 already
  installed with `nix-command flakes` enabled, standalone Home Manager 25.11-pre already
  installed, no existing Home Manager configuration to migrate.

## Explicitly out of scope for version 1

- Remote or fleet deployment tooling (deploy-rs, colmena, nixops).
- macOS / nix-darwin, WSL.
- CI pipeline (a local `nix flake check` is enough for v1).
- Disk partitioning (disko), impermanence, secure boot.
- Desktop environment theming and GUI application configuration beyond installing apps.

## Success criteria

- Running the single apply command on the first host (Pop!_OS) yields git, tmux, `vim`,
  `vim-cpp`, and `vim-py` on PATH with my configuration, and a secret managed through
  sops-nix is readable by my user after activation.
- In `vim-cpp`, I can set a breakpoint in a small C++ program, start gdb from Vim, step,
  and inspect a variable. In `vim-py`, the same with debugpy on a small Python script.
- A second, NixOS host is defined in the repo, builds with `nix flake check` from the
  first host, and shares the base layer unchanged.
- Adding a third host requires touching only `hosts/<name>/` and one line in `flake.nix`.
- `nix flake check` passes on a clean checkout.

## Suggested phasing

1. Flake skeleton, first host (this Pop!_OS machine) as standalone Home Manager, base
   layer with git and tmux, `nix flake check` and formatter wired up.
2. Vim: shared core, then `vim-cpp` and `vim-py` flavors with working debuggers.
3. Secrets with sops-nix on the standalone Home Manager host.
4. First NixOS host: shared NixOS modules, Home Manager as NixOS module reusing
   `modules/home`, secrets on NixOS.
5. Bootstrap scripts and docs; verify by bootstrapping a fresh VM of each kind.

## Open decisions I want to be asked about

- The host inventory: names, distro, architecture, and role of each machine.
- Vim debugging integration: vimspector versus Vim's built-in termdebug for C++ and a
  separate adapter for Python.
- Which nixpkgs branch to pin: `nixos-unstable` or the current stable release.
- Which shell to manage (bash, zsh, fish) and whether it belongs in the base layer.
- Whether GUI applications should be installed through Nix on non-NixOS hosts or left to
  the distro.
