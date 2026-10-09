# Phase 2: Base User Environment - Research

**Researched:** 2026-10-08
**Domain:** Home Manager user-environment modules (git / tmux / bash / plain vim) on standalone non-NixOS
**Confidence:** HIGH (option names, shapes, and defaults verified this session against the pinned HM release-26.05 source and by live `nix eval` probes of the real composed config)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Module Organization
- **D-01:** Split base modules into separate files (`git.nix`, `tmux.nix`, `bash.nix`, `vim.nix`) imported from `modules/base/default.nix` — keeps modules discoverable and composable while following the Base→Roles→Host layering. — **Reversibility:** reversible — can consolidate later without breaking callers.
- **D-02:** Keep each module self-contained (enable its `programs.*` options, set minimal config). Do not cross-reference between tool modules except via shared paths/config already provided by Home Manager context. — **Reversibility:** reversible

#### Git Configuration (NIX-05)
- **D-03:** Enable `programs.git.enable = true` with minimal sensible defaults (user.name, user.email, init.defaultBranch, core.editor, pull.rebase). Keep identity values simple (can be overridden per-host later if needed). Do not enable commit signing by default in Phase 2. — **Reversibility:** reversible — can add signing config in later phase.
- **D-04:** Set `core.editor` to `vim` (ties to the managed vim). Keep aliases minimal (e.g., `status`, `log --oneline`) — avoid heavy alias sets. — **Reversibility:** reversible

#### Tmux Configuration (NIX-05)
- **D-05:** Enable `programs.tmux.enable = true` with conservative defaults: vi mode on, mouse off (or configurable), sensible escape-time/history-limit. No external tmux plugins in Phase 2 — keep vanilla managed config. — **Reversibility:** reversible — plugins can be added later if needed.
- **D-06:** Prefix key remains default `Ctrl-b` (Home Manager default). Avoid custom keybindings beyond essentials; prioritize clarity over personalization. — **Reversibility:** reversible

#### Bash Management (NIX-15)
- **D-07:** Enable `programs.bash.enable = true` and ensure bash is the managed base shell. Configure minimal, non-invasive `.bashrc` (history settings, PS1 if needed) without overriding system-wide behavior. — **Reversibility:** reversible
- **D-08:** Rely on Home Manager session env via login shells; no aggressive PATH manipulation beyond what HM provides. — **Reversibility:** reversible

#### Plain Vim (NIX-07)
- **D-09:** For Phase 2, provide plain vim via `programs.vim.enable = true` with shared core settings only (syntax on, filetype detection, nocompatible baseline, sensible search/indentation, line numbers). This satisfies "plain vim available with common core only" while keeping Phase 2 simple. — **Reversibility:** reversible
- **D-10:** Keep vim package as default from nixpkgs (not vim-full) for plain vim in Phase 2. Flavored vims (vim-cpp/vim-py) will use `vim-full.customize` in Phase 3; the shared core vimrc/config will be extracted/reused so both paths share the same core settings. — **Reversibility:** reversible — structure allows migrating plain vim to customized build in Phase 3 without breaking behavior.
- **D-11:** Do not add any plugins to plain vim in Phase 2. Plugins belong to flavored vims (Phase 3) per the constraint "no runtime fetching" and flavor isolation. — **Reversibility:** reversible

#### Integration & Verification
- **D-12:** Wire modules into `modules/base/default.nix` by importing the split tool modules (order: git, tmux, bash, vim — order shouldn't matter functionally). — **Reversibility:** reversible
- **D-13:** Keep existing `targets.genericLinux.enable = true` and the hello marker in the host home entrypoint as-is; Phase 2 adds real modules without removing the marker (can keep or remove later — non-functional). — **Reversibility:** reversible
- **D-14:** Verification: after `home-manager switch --flake .#razer-blade`, `git --version`, `tmux -V`, `bash --version`, `vim --version` all report Nix-provided binaries; plain `vim` loads with core settings. Also `nix flake check` must still pass. — **Reversibility:** N/A (verification)

### the agent's Discretion
- Exact PS1/history values for bash (keep minimal, conventional)
- Exact vim core settings set (sensible defaults; avoid heavy customizations)
- Git identity placeholders (e.g., user.name "User", user.email "user@example.com") are fine if not overridden — Home Manager will manage them; can be refined later

### Deferred Ideas (OUT OF SCOPE)
CONTEXT.md contains no explicit `## Deferred Ideas` section. The phase boundary (`<domain>`) defines what is out of scope and is reproduced verbatim here: vim-cpp/vim-py flavors (Phase 3), vimspector (Phase 4), and secrets (Phase 5) are NOT part of Phase 2. Any tmux plugin, any vim plugin, and any git commit signing are intentionally deferred.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NIX-05 | Include base tools on all machines (git, tmux, vim, vim-cpp, vim-py) | Phase 2 delivers the base slice: `programs.git`, `programs.tmux`, and the plain `programs.vim` (the `vim` member of the set); vim-cpp/vim-py are Phase 3 (NIX-06). Exact release-26.05 option names/shapes verified against pinned HM source and live eval. |
| NIX-07 | Keep plain vim available with common core only | `programs.vim.enable = true` emits a customized package named `vim`; HM's default `packageConfigurable` is **vim-full** and its default `plugins` includes `vim-sensible` — both must be overridden (`pkgs.vim`, `lib.mkForce []`) to meet "plain, no plugins" (verified empirically). Core settings via `extraConfig` (`syntax`/`filetype`) + `settings` (number/search/indent). |
| NIX-15 | Manage bash as base shell | `programs.bash.enable = true` manages `~/.bashrc`, `~/.bash_profile`, `~/.profile` and sources `hm-session-vars.sh` from `~/.profile`, so `home.sessionVariables` load on login; `package = bashInteractive` default; aliases/history options verified. |
</phase_requirements>

## Project Constraints (from AGENTS.md)

Actionable directives extracted from `/home/tim/prj/nixify/AGENTS.md` (sources: PROJECT.md, STACK.md, workflow enforcement). The planner must not recommend approaches that contradict these:

| # | Directive | Source | Phase-2 Relevance |
|---|-----------|--------|-------------------|
| C1 | **Nix flakes only** — pure evaluation, no channels, no `nix-env`, no imperative state | PROJECT.md | All four modules are declarative HM module options; no imperative shell setup. |
| C2 | **Single nixpkgs input** pinned to `nixos-26.05`; HM + sops-nix `follows` it | PROJECT.md + STACK.md | Every tool/package comes from the one pinned nixpkgs input; no new inputs. |
| C3 | **Home Manager** as NixOS module on NixOS, standalone elsewhere, **sharing `modules/home`** | PROJECT.md | Phase 2 modules live in `modules/base/` (imported by the composer) and are host-kind agnostic so Phase 7 reuses them under the NixOS HM module unchanged. |
| C4 | **Secrets security** — plaintext never in repo or world-readable store; one age key per host | PROJECT.md | No secrets in Phase 2; git identity (name/email) is not a credential. Signing explicitly off (D-03). |
| C5 | **Vim constraints** — Vim proper, flavors side-by-side, plugins pinned in Nix, **no runtime fetching** | PROJECT.md | Phase 2 has no plugins at all (D-11); `lib.mkForce []` guarantees zero plugin packages and therefore zero runtime fetching. |
| C6 | **No flake-utils / flake-parts** | STACK.md | Not touched; modules are plain HM modules. |
| C7 | Adding a host = `hosts/<name>/` + one line in `hosts/default.nix`; flake.nix untouched | STACK.md/AGENTS.md | Phase 2 edits `modules/base/` only; flake.nix and the registry stay untouched. |
| C8 | Checks are per-system; run on the machine or `--all-systems` | STACK.md | Phase 2 adds no new checks; the existing `home-razer-blade` activation check builds the new modules. |
| C9 | **GSD workflow** — do not make direct repo edits outside a GSD workflow | AGENTS.md | Executor must run the plan through `/gsd-execute-phase`. |
| C10 | `nixfmt` (RFC 166) is the formatter, wired to `nix fmt` + `checks` | STACK.md | Every new `.nix` file must be `nix fmt`-clean or the existing `fmt` gate fails `nix flake check`. |

Conventions file is empty ("will populate as patterns emerge"); no project skills and no `rules/*.md` files exist — no additional constraints.

## Summary

Phase 2 is a **module-surface phase**: it adds four self-contained Home Manager modules under `modules/base/` and imports them from `modules/base/default.nix`, leaving the Phase-1 flake, registry, composer, checks, and formatter untouched. The research below is not a design guess — every option name, type, default, and generated file path was **verified this session against the exact HM revision pinned in `flake.lock`** (`home-manager` release-26.05, rev `a6631107…`) by reading the option definitions from the store source and by evaluating a live `homeManagerConfiguration` probe with the real modules enabled.

**Two locked decisions collide with Home Manager's defaults and must be handled explicitly** (both empirically verified):

1. **Plain vim is not HM's default vim.** D-10 requires the default nixpkgs `vim` (not `vim-full`), but `programs.vim.packageConfigurable` defaults to `pkgs.vim-full` (vim.nix:153). Set `programs.vim.packageConfigurable = pkgs.vim;` to honor D-10.
2. **"No plugins" is not the HM default.** `programs.vim.plugins` defaults to `[ pkgs.vimPlugins.vim-sensible ]` and the module re-asserts it (vim.nix:16, 101, 222). Because the option type is `listOf`, setting `plugins = []` **concatenates to `[ vim-sensible ]`, not `[]`** (verified: probe returned `["vim-sensible"]`). D-11 requires `programs.vim.plugins = pkgs.lib.mkForce [ ];` (verified: probe returned `[]`).

Similarly, git's modern option is `programs.git.settings` (an attrset). The older `userName`/`userEmail`/`aliases`/`extraConfig` names still work but are renamed aliases that emit deprecation warnings on 26.05 (`extraConfig`→`settings`, `aliases`→`settings.alias`, `userName`→`settings.user.name`, `userEmail`→`settings.user.email`; verified in git.nix:296-344 and by a warning-emitting probe). The planner should use the canonical `settings` form. tmux and bash option names match the obvious names and their defaults already satisfy D-05/D-06/D-07 (vi mode is the one deliberate override).

**Primary recommendation:** Create `modules/base/{git,tmux,bash,vim}.nix` (+ a shared `lib/vim-core.nix` carrying the vimscript core string for Phase-3 reuse) and import them from `modules/base/default.nix`. Use `programs.git.settings`, `programs.tmux.{enable,keyMode="vi"}`, `programs.bash.enable` + `home.sessionVariables`, and `programs.vim` with `packageConfigurable = pkgs.vim` + `plugins = lib.mkForce []` + `extraConfig = coreRC`. Verify with `nix flake check` and `nix build .#homeConfigurations.razer-blade.activationPackage`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Git config (`programs.git`) | HM module (`modules/base/git.nix`) | nixpkgs (`pkgs.git`) | Declarative option → `~/.config/git/config` + `git` package in the profile; no imperative `git config`. |
| tmux config (`programs.tmux`) | HM module (`modules/base/tmux.nix`) | nixpkgs (`pkgs.tmux`) | Option → `~/.config/tmux/tmux.conf` + package; prefix/keymode owned by the module. |
| Bash rc + session env (`programs.bash`) | HM module (`modules/base/bash.nix`) | HM core (`home.sessionVariables`) | Shell module owns `~/.bashrc`/`.profile`; session vars are an HM-core concern sourced by the shell module. |
| Plain vim package + core (`programs.vim`) | HM module (`modules/base/vim.nix`) | nixpkgs (`pkgs.vim`) + shared core string (`lib/vim-core.nix`) | One customized `vim` executable; core vimscript string is the reuse seam for Phase 3 flavors. |
| Module composition | Composer (`modules/base/default.nix` imported by `lib/composer.nix`) | — | D-12: the Base layer root imports the four modules; composer is unchanged. |
| Host identity / env baseline | Registry + host layer (already in place) | — | D-13: `targets.genericLinux` + hello marker stay as-is; modules are additive. |

## Standard Stack

### Core

| Library / Module | Version | Purpose | Why Standard |
|------------------|---------|---------|--------------|
| Home Manager `programs.git` | HM `release-26.05` (flake input, `follows` nixpkgs) | Git config + `pkgs.git` in profile | The only declarative git module in HM; writes `~/.config/git/config`. [VERIFIED: modules/programs/git.nix @ rev a6631107] |
| Home Manager `programs.tmux` | HM `release-26.05` | tmux config + `pkgs.tmux` | Native HM module; writes `~/.config/tmux/tmux.conf`; exposes `keyMode`/`mouse`/`escapeTime`/`historyLimit`/`prefix`. [VERIFIED: modules/programs/tmux.nix] |
| Home Manager `programs.bash` | HM `release-26.05` | Managed `~/.bashrc`, `~/.bash_profile`, `~/.profile` | Manages interactive + login rc; sources `hm-session-vars.sh` from `.profile` so `home.sessionVariables` load at login. [VERIFIED: modules/programs/bash.nix] |
| Home Manager `programs.vim` | HM `release-26.05` | One customized plain `vim` executable | `programs.vim` supports exactly one vim (STACK.md); correct for the "plain vim" requirement in Phase 2. [VERIFIED: modules/programs/vim.nix] |
| `home.sessionVariables` | HM core `release-26.05` | Session/login environment variables | Canonical HM mechanism; bash module sources the generated `hm-session-vars.sh` at login (D-08). [VERIFIED: probe produced `home.sessionVariablesPackage`] |
| nixpkgs | `nixos-26.05` (single input) | Package set | `pkgs.git`, `pkgs.tmux`, `pkgs.bashInteractive`, `pkgs.vim` all resolve from the one pinned input. [VERIFIED: pinned flake.lock] |
| Nix | 2.35.2 (installed) | Flake eval/build | Flakes stable; all commands used (`nix flake check`, `nix build`, `nix eval`, `nix fmt`) supported. [VERIFIED: `nix --version`]. ⚠️ STACK.md/STATE.md claim 2.29 — stale. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `pkgs.lib.mkForce` | nixpkgs 26.05 | Override a `listOf` default that otherwise concatenates | Required for `programs.vim.plugins = lib.mkForce [ ]` (D-11). [VERIFIED: probe] |
| `lib/vim-core.nix` (new, plain Nix string) | n/a (repo file) | Single source of truth for vim core vimscript | Consumed by `modules/base/vim.nix` in Phase 2 and by the flavored-vim module in Phase 3 (D-10 forward-compat). |

### Package Legitimacy Audit

Not applicable to this ecosystem: no npm/PyPI/crates/RubyGems packages are introduced. Every executable comes from the already-pinned nixpkgs input (Phase 1 locked and audited the flake inputs); Phase 2 adds **no new flake inputs, no new packages**, only HM option wiring. All derivations referenced (`git`, `tmux`, `bashInteractive`, `vim`) are attributes of the pinned nixpkgs tree and are buildable offline from the lock. The only "new" file is a plain Nix string in-repo (`lib/vim-core.nix`), which is not a package source.

## Architecture Patterns

### System Architecture Diagram

```
  flake.nix (unchanged)
        │  mkHomeConfiguration → lib/composer.nix
        ▼
  lib/composer.nix  (unchanged)
        │  moduleList = base → roles → hosts/<name>/home.nix
        ▼
  modules/base/default.nix   ◄── D-12: gains imports
        │  imports
        ├─► modules/base/git.nix    ── programs.git      ─► ~/.config/git/config ; pkgs.git
        ├─► modules/base/tmux.nix   ── programs.tmux     ─► ~/.config/tmux/tmux.conf ; pkgs.tmux
        ├─► modules/base/bash.nix   ── programs.bash     ─► ~/.bashrc, ~/.bash_profile, ~/.profile
        │                                              └─► home.sessionVariables (via hm-session-vars.sh)
        └─► modules/base/vim.nix    ── programs.vim      ─► customized `vim` (pkgs.vim) ; coreRC
                 │  import
                 └─► lib/vim-core.nix  (plain string: coreRC)  ◄── reused by Phase 3 flavors
        │
        ▼
  hosts/razer-blade/home.nix  (unchanged; targets.genericLinux + hello marker stay, D-13)
        │
        ▼
  homeConfigurations.razer-blade.activationPackage  ── build/verify via `nix build`
```

### Recommended Project Structure

```
modules/base/
├── default.nix      # imports: ./git.nix ./tmux.nix ./bash.nix ./vim.nix
├── git.nix          # programs.git = { enable = true; settings = {...}; }
├── tmux.nix         # programs.tmux = { enable = true; keyMode = "vi"; ... }
├── bash.nix         # programs.bash = { enable = true; ... }; home.sessionVariables = {...}
└── vim.nix          # programs.vim = { enable = true; packageConfigurable = pkgs.vim;
                      #                  plugins = lib.mkForce []; extraConfig = coreRC; }
lib/
└── vim-core.nix     # { coreRC = ''...''; }  — shared core vimscript (Phase 2 + Phase 3)
```

`modules/base/default.nix` stays a plain module (currently `{ config, lib, ... }: { }`) and only adds an `imports = [ ./git.nix ./tmux.nix ./bash.nix ./vim.nix ];`. No signature/arg changes are required, so `lib/composer.nix` is untouched.

### Pattern 1: One self-contained module per tool

Each module takes only `{ pkgs, lib, ... }` (or `{ config, ... }`) and sets its own `programs.<tool>` options. No module imports another tool module. [CONTEXT D-01/D-02]

### Pattern 2: Shared core as a plain Nix value, not a module

Because `modules/base/default.nix` is imported as a *module directory* by the composer, any `.nix` file placed inside `modules/base/` that is *imported by default.nix* becomes a module. The shared vim core is **data (a string), not a module**, so it lives in `lib/vim-core.nix` and is `import`ed by `vim.nix` as a plain expression. This keeps the module list clean and gives Phase 3 a single import seam. [CONTEXT D-10]

### Pattern 3: Canonical git option namespace

Use `programs.git.settings` (attrset or ordered list). Reserved/dotted keys like `core.editor` are expressed as nested attrs: `settings = { user = { name, email }; init.defaultBranch = "main"; core.editor = "vim"; pull.rebase = true; alias = {...}; }`. Avoid the deprecated renamed options to keep eval warning-free. [VERIFIED: git.nix:296-344]

### Anti-Patterns to Avoid

- **Setting `programs.vim.plugins = [ ];` expecting zero plugins** — it concatenates with the module's forced `[ vim-sensible ]`. Use `lib.mkForce [ ]`. [VERIFIED: probe]
- **Leaving `programs.vim.packageConfigurable` at default** — that is `pkgs.vim-full`, contradicting D-10's plain-vim intent. [VERIFIED: vim.nix:153]
- **Using `programs.vim.settings` for `syntax`/`filetype`** — those are not in HM's known-settings enum; `settings` is a closed submodule. Put `syntax on` / `filetype plugin indent on` / `set nocompatible` in `extraConfig` (the core string). [VERIFIED: vim.nix knownSettings]
- **Using deprecated git aliases (`userName`, `userEmail`, `aliases`, `extraConfig`)** — works but emits deprecation warnings on 26.05. [VERIFIED: probe]
- **Custom tmux prefix in Phase 2** — D-06 says keep `Ctrl-b`; leave `prefix = null`. [VERIFIED: tmux.nix default]
- **Adding any flake input or `pkgs.*` fetch for these tools** — violates single-input (C2) and no-runtime-fetch (C5).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Git config file management | `home.file.".gitconfig".text` or a `git config` activation script | `programs.git.settings` | HM owns path/merge/type-checking; writes XDG config and manages the package. |
| tmux config file | `home.file.".tmux.conf".text` | `programs.tmux` options (+ `extraConfig`) | HM emits the file at the XDG path; option types give validation and defaults. |
| Bash rc / login env | Hand-written `.bashrc`/`.profile` via `home.file` | `programs.bash` + `home.sessionVariables` | Avoids clobbering/login-shell mistakes; HM sources session vars from `.profile` correctly. |
| Vim core settings | A raw `~/.vimrc` written by `home.file` | `programs.vim.enable` + `extraConfig` (shared core string) | A `customize`d vim ignores `~/.vimrc`; settings must go through the module's `customRC`. |
| Force-overriding defaults | Nix overlay/patch of HM | `pkgs.lib.mkForce` | Idiomatic, minimal, and the only correct way for `listOf` options. |

**Key insight:** this phase is pure *declarative wiring*. There is no custom algorithm to write — the risk is entirely in matching the pinned HM option contract, which is why this research verified every option against the source rather than the general docs.

## Common Pitfalls

### Pitfall 1: `programs.vim.plugins = []` does not remove plugins
**What goes wrong:** A fresh `vim` still loads `vim-sensible` (from the store), so D-11 "no plugins" is silently violated and flavor isolation is undermined.
**Why it happens:** `plugins` is `types.listOf`; the module does `plugins = defaultPlugins ++ cfg.plugins`, and `[] ++ [vim-sensible] = [vim-sensible]`. [VERIFIED: vim.nix:101,222 + probe returning `["vim-sensible"]`]
**How to avoid:** `programs.vim.plugins = pkgs.lib.mkForce [ ];` → probe returned `[]`. [VERIFIED]
**Warning signs:** `nix eval` reports a non-empty plugin list; `nix-store -q --references` on the vim wrapper shows a `vim-sensible` path.

### Pitfall 2: HM's default plain-vim package is `vim-full`
**What goes wrong:** The "plain vim" ends up being a huge build with python3, contradicting D-10 and blurring the Phase-3 flavor distinction.
**Why it happens:** `packageConfigurable` defaults to `mkPackageOption pkgs "vim-full"`. [VERIFIED: vim.nix:153]
**How to avoid:** set `programs.vim.packageConfigurable = pkgs.vim;`. (Verified this still yields an executable named `vim`.) Note: plain `pkgs.vim` **does** support `.customize` — the probe evaluated it successfully.

### Pitfall 3: Deprecated git option names warn on 26.05
**What goes wrong:** `programs.git.userName`, `.userEmail`, `.aliases`, `.extraConfig` are **renamed aliases**; using them prints deprecation warnings and may be removed in a later release.
**Why it happens:** 26.05 renamed these to `settings`/`settings.alias`/`settings.user.*`. [VERIFIED: git.nix:296-344]
**How to avoid:** use `programs.git.settings` with nested attrs. [CONTEXT D-03/D-04 mention the old names; prefer canonical.]

### Pitfall 4: A stale `~/.gitconfig` or `~/.tmux.conf` shadows the managed file
**What goes wrong:** git reads `~/.gitconfig` **after** `$XDG_CONFIG_HOME/git/config`, so an old hand-edited `~/.gitconfig` overrides single-valued settings from HM's XDG file; tmux reads `~/.tmux.conf` **before** the XDG file, so an old `~/.tmux.conf` wins entirely.
**Why it happens:** documented search orders. [CITED: https://git-scm.com/docs/git-config#FILES ; CITED: https://man7.org/linux/man-pages/man1/tmux.1.html]
**How to avoid:** during migration, remove/rename pre-existing `~/.gitconfig` and `~/.tmux.conf` so the HM-managed XDG files take effect. HM backs up regular files it would overwrite, but it does not delete unrelated dotfiles.
**Warning signs:** `git config --list --show-origin` shows a `file:/home/tim/.gitconfig` origin after switch.

### Pitfall 5: `.profile` / `.bash_profile` vs `.bashrc` confusion
**What goes wrong:** expecting `home.sessionVariables` in a non-login interactive shell, or double-sourcing.
**Why it happens:** `programs.bash` writes `.profile` (sources `hm-session-vars.sh`) and `.bash_profile`; session vars load on **login**. [VERIFIED: bash.nix:224-274]
**How to avoid:** treat session vars as login-time; if values are needed in nested interactive shells, they are inherited from the login environment (default). [CONTEXT D-08]

### Pitfall 6: `nix flake check` sees only committed files
**What goes wrong:** newly created `modules/base/*.nix` are invisible to the flake; the check passes against the old tree or fails with "path does not exist."
**Why it happens:** Nix flakes copy only git-tracked (or staged) files in a dirty tree; untracked files are ignored.
**How to avoid:** `git add` the new module files before running `nix flake check` / `nix build` (Phase 1 already relies on this). Note: `path.exists`/config errors will surface otherwise.

## Code Examples

Verified against the pinned HM release-26.05 source and evaluated with a live probe. [VERIFIED: HM modules @ rev a6631107 + `nix eval` probes]

### `modules/base/git.nix`
```nix
{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "User";                 # discretion placeholder; override per host later
        email = "user@example.com";
      };
      init.defaultBranch = "main";
      core.editor = "vim";             # D-04: ties to managed vim
      pull.rebase = true;
      alias = {
        st = "status";
        lg = "log --oneline";
      };
    };
    # signing intentionally NOT enabled (D-03)
  };
}
```

### `modules/base/tmux.nix`
```nix
{ ... }:
{
  programs.tmux = {
    enable = true;
    keyMode = "vi";            # D-05; default is "emacs"
    mouse = false;             # D-05 (default false)
    escapeTime = 10;           # default
    historyLimit = 10000;      # D-05 "sensible"; HM default is 2000
    # prefix stays default Ctrl-b (D-06); no plugins (D-05)
    extraConfig = ''
      set -g base-index 1
      setw -g pane-base-index 1
    '';
  };
}
```
Generated file (verified): `~/.config/tmux/tmux.conf` containing `set -g status-keys vi`, `set -g mode-keys vi`, `set -g escape-time 10`, `set -g history-limit 10000`, and no `prefix` override.

### `modules/base/bash.nix`
```nix
{ pkgs, ... }:
{
  programs.bash = {
    enable = true;
    # package defaults to pkgs.bashInteractive
    shellAliases = {
      ll = "ls -alF";
      ".." = "cd ..";
    };
    historyControl = [ "ignoredups" "ignorespace" ];
    historySize = 10000;
    initExtra = ''
      # minimal interactive-only additions
    '';
  };

  # D-08: session vars via HM core; bash module sources them from ~/.profile
  home.sessionVariables = {
    EDITOR = "vim";
    PAGER = "less";
  };
}
```
Verified generated files: `~/.bashrc`, `~/.bash_profile`, `~/.profile`, `/home/tim/.config/environment.d/10-home-manager.conf`, plus `home.sessionVariablesPackage` = `hm-session-vars.sh`. `~/.profile` sources `${sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh`.

### `lib/vim-core.nix` (plain data, shared with Phase 3)
```nix
# Not a module — a plain attrset consumed via `import ../lib/vim-core.nix`.
rec {
  coreRC = ''
    set nocompatible
    syntax on
    filetype plugin indent on
    set number
    set relativenumber
    set ignorecase smartcase
    set expandtab shiftwidth=2 tabstop=2
    set hidden
    set backspace=indent,eol,start
  '';
}
```

### `modules/base/vim.nix`
```nix
{ pkgs, lib, ... }:
let
  inherit (import ../../lib/vim-core.nix) coreRC;
in
{
  programs.vim = {
    enable = true;
    packageConfigurable = pkgs.vim;   # D-10: plain vim, NOT vim-full (HM default is vim-full)
    plugins = lib.mkForce [ ];        # D-11: zero plugins (listOf would otherwise re-add vim-sensible)
    extraConfig = coreRC;             # carries syntax/filetype/nocompatible + core settings
    # settings = { ... };             # optional: only keys in HM's knownSettings enum are valid here
  };
}
```

### `modules/base/default.nix`
```nix
{ config, lib, ... }:
{
  imports = [
    ./git.nix
    ./tmux.nix
    ./bash.nix
    ./vim.nix
  ];
}
```

## State of the Art

| Old Approach | Current Approach (26.05) | When Changed | Impact |
|--------------|--------------------------|--------------|--------|
| `programs.git.userName` / `userEmail` / `aliases` / `extraConfig` | `programs.git.settings` (+ `settings.alias`, `settings.user.*`) | HM 25.05+, renamed aliases in 26.05 | Use canonical form; old names warn. [VERIFIED] |
| `vim_configurable` package | `vim-full` (+ plain `vim`) | nixpkgs 24.11+ | Phase 3 flavors use `vim-full.customize`; Phase 2 plain vim uses `pkgs.vim`. |
| Plain `nixfmt` = classic | `nixfmt` = RFC-style; classic = `nixfmt-classic`; flake uses `nixfmt-tree` | nixpkgs 25.11+ | New files must be RFC-166 formatted (existing `fmt` check already enforces this). |

**Deprecated/outdated:** STACK.md/STATE.md state Nix `2.29`; the installed Nix is `2.35.2` [VERIFIED: `nix --version`]. No action needed, but note the descrepancy.

## Assumptions Log

| # | Claim | Section | Risk if Wrong | Tag & How to Confirm |
|---|-------|---------|---------------|----------------------|
| A1 | Git identity placeholders ("User" / "user@example.com") are acceptable for Phase 2; real values come later | Code Examples / `git.nix` | Low-med: commits are mis-attributed until overridden | [ASSUMED] — CONTEXT "agent's Discretion" explicitly permits placeholders; confirm preference at plan/discuss time |
| A2 | D-10 "default from nixpkgs (not vim-full)" maps to `pkgs.vim` | Summary / Pitfall 2 | Low: wrong package selected | [VERIFIED: option default is `vim-full`; `pkgs.vim` evaluates and yields `vim`] — verify D-10 intent verbally if ambiguous |
| A3 | "shared core vimrc/config" means core **settings only**, not importing an external `~/.vimrc` | Architecture / `lib/vim-core.nix` | Low: rework of the core file | [ASSUMED] — repo contains no vimrc; CONTEXT lists explicit core items |
| A4 | Pre-existing hand-edited `~/.gitconfig` / `~/.tmux.conf` / `~/.bashrc` on razer-blade may shadow HM output | Pitfall 4 | Med: managed config seems ineffective | [CITED: git/tmux docs search order] — inspect the machine at execute time; remove/rename stale files |
| A5 | tmux XDG config is the effective file because no `~/.tmux.conf` exists on the host | Pitfall 4 / tmux | Med: vi-mode etc. not applied | [CITED: tmux man page] — check `test -e ~/.tmux.conf` before/after switch |
| A6 | Installed Nix is 2.35.2; STACK/STATE's 2.29 is stale | Standard Stack | None | [VERIFIED: `nix --version`] |
| A7 | `lib.mkForce [ ]` for `programs.vim.plugins` is the intended mechanism and Phase 3 flavor isolation will use a different path (`vim-full.customize`), so the force does not leak | Pitfall 1 / vim | Low: possibly redundant force in Phase 3 | [VERIFIED: probe] + Phase 3 design in STACK.md uses `customize`, not `programs.vim` |
| A8 | No plugin in Phase 2 means zero runtime fetching (satisfies C5) | Pitfalls / Security | Low | [VERIFIED: `plugins` forced `[]`; HM only warns for plugins when `sensibleOnTop`/defaults used] |
| A9 | bash's default `package = bashInteractive` is acceptable (no explicit package override needed) | bash.nix | Low | [VERIFIED: bash.nix option default] |

## Open Questions (RESOLVED)

All four questions below are resolved; the resolutions are implemented by `02-01-PLAN.md`.

| # | Question | Why It Matters | Recommendation | Resolution |
|---|----------|----------------|----------------|------------|
| Q1 | Should real git `user.name`/`user.email` be set now, or placeholders until a later host-override phase? | Commit attribution + who owns identity (base vs host) | Keep placeholder in base (D-03 says identity "can be overridden per-host later"); optionally let the host set real values. Decide at discuss/plan. | **RESOLVED:** keep placeholder identity (`"User"` / `"user@example.com"`) in the base module per D-03; real values are overridable per host later (implemented in 02-01-PLAN Task 1). |
| Q2 | Where should the shared vim core live — `lib/vim-core.nix` (not a module) vs `modules/base/vim-core.nix`? | Avoids accidentally registering a non-module in the Base import list | Recommend `lib/vim-core.nix` (plain data) imported by `vim.nix`. | **RESOLVED:** shared core lives in `lib/vim-core.nix` as plain data (not a module), imported by `modules/base/vim.nix` (implemented in 02-01-PLAN Task 3). |
| Q3 | Should plain vim use `extraConfig` only (all core in the string) or split supported keys into `programs.vim.settings`? | Affects Phase-3 reuse fidelity | Recommend all-in-`coreRC` so the exact string is reused as `customRC` in Phase 3. | **RESOLVED:** all core settings live in the `extraConfig`/`coreRC` string so the exact string is reused as `customRC` in Phase 3 (implemented in 02-01-PLAN Task 3). |
| Q4 | History limit / tmux extra binds within D-05's "sensible" | Cosmetic/personalization | Pick conservative values in the plan; not blocking. | **RESOLVED:** conservative `historyLimit = 10000` and default `Ctrl-b` prefix binds, no extra keybindings (implemented in 02-01-PLAN Task 2). |

## Environment Availability

Minimal: this phase needs only the installed Nix toolchain and the pinned flake inputs — no external services, databases, or runtimes. [VERIFIED this session]

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Nix (flakes) | eval/build/check | ✓ | 2.35.2 | — |
| git | repo + `programs.git` | ✓ | installed | — |
| Home Manager (flake input) | all modules | ✓ | release-26.05, rev a6631107 | — |
| nixpkgs (flake input) | all packages | ✓ | nixos-26.05 | — |
| `jq` | (not needed) | ✗ | — | use `nix eval --json` + `python3`; `jq` absent (earlier silent failures were masked by this) |
| python3 | probe/JSON parsing | ✓ | /usr/bin/python3 | — |

No environment blockers.

## Validation Architecture

Nyquist enabled (config.json `workflow.nyquist_validation`). The project has **no unit-test framework** — this is a declarative Nix config, so the "test runner" is the Nix flake/CLI itself. Validation is therefore content-assertion via `nix eval` + build success via `nix flake check`/`nix build`.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Nix flake `checks` + `nix eval` assertions (no Jest/pytest/etc.) |
| Config file | `flake.nix` (`checks.${system}."home-<host>"` + `fmt`), unchanged |
| Quick run command | `nix flake check` (after `git add` of new modules) |
| Full suite command | `nix flake check --all-systems`; per-host `nix build .#homeConfigurations.razer-blade.activationPackage` |

### Phase Requirements → Test Map
| Req | Behavior | Test Type | Automated Command | File Exists? |
|-----|----------|-----------|-------------------|--------------|
| NIX-05 (git) | git enabled; settings rendered; `git` in profile | eval + build | `nix eval --json .#homeConfigurations.razer-blade.config.programs.git.settings` and `nix build .#homeConfigurations.razer-blade.activationPackage` | ✅ (check exists) |
| NIX-05 (tmux) | tmux enabled; vi mode in generated conf | eval + build | `nix eval --raw '.#homeConfigurations.razer-blade.config.xdg.configFile."tmux/tmux.conf".text'` (grep `mode-keys vi`) | ✅ |
| NIX-07 | plain vim; **zero** plugins; core settings present | eval | `nix eval --json .#homeConfigurations.razer-blade.config.programs.vim.plugins` → `[]`; `…programs.vim.packageConfigurable.name` → `"vim"` | ✅ |
| NIX-15 | bash enabled; rc/profile managed; session vars package present | eval + build | `nix eval --json .#homeConfigurations.razer-blade.config.programs.bash.enable`; `nix eval --json .#homeConfigurations.razer-blade.config.home.file` (keys include `~/.bashrc`,`~/.profile`) | ✅ |
| D-14 (manual) | binaries report Nix paths after switch | manual UAT | `git --version; tmux -V; bash --version; vim --version` on host | N/A |

### Sampling Rate
- **Per task commit:** `git add <new modules> && nix flake check` + `nix fmt`
- **Per wave merge:** `nix flake check --all-systems`
- **Phase gate:** full green `nix flake check` + successful `nix build .#homeConfigurations.razer-blade.activationPackage`; then D-14 manual UAT on razer-blade.

### Wave 0 Gaps
- [ ] None strictly required — Phase 1 already provides `checks."home-razer-blade"` (activation package) and the `fmt` check. New modules are exercised automatically once imported.
- [ ] **Optional** hardening: add a small `checks` derivation (e.g., `pkgs.runCommand` over the generated `git/config`, `tmux/tmux.conf`, `.bashrc`) that greps for required strings (`mode-keys vi`, `git` settings, `syntax on`), turning content assertions into CI-gated checks rather than ad-hoc `nix eval`. Not needed for correctness; recommend only if the phase wants durable regression protection for "no plugins"/"plain vim".
- [ ] Ensure new files are `git add`-ed before `nix flake check` (Pitfall 6).

## Security Domain

ASVS Level 1 applies (config is local, single-user, no network service). Most ASVS chapters are N/A because there is no application, authentication, or cryptography in scope.

| ASVS Category | Applies | Standard Control / Mitigation |
|---------------|---------|-------------------------------|
| V1 Architecture | Partial | Declarative, pure-eval modules; no imperative state (C1). |
| V2 Authentication | No | No auth surface. |
| V3 Session Management | No | No sessions beyond a local login shell. |
| V4 Access Control | No | Single user; no privileged operations in Phase 2 (no NixOS system module). |
| V5 Input Validation | Partial | HM option types type-check all values at eval; `settings` is a closed submodule, `keyMode` an enum, etc. [VERIFIED] |
| V6 Cryptography | No | No crypto; git commit signing explicitly **disabled** (D-03). |
| V7 Error/Logging | Partial | Deprecation warnings surface bad option use (Pitfall 3). |
| V8 Data Protection | Yes | Secrets are entirely out of scope (Phase 5); nothing sensitive is written to the world-readable store. Git identity is not a credential. |
| V9 Communications | No | No runtime network access; **no runtime plugin/gadget fetching** (C5). |
| V10 Malicious Code | Yes | All packages from the pinned nixpkgs input; **no new inputs/packages** (single-input, C2); flake.lock pins revisions. |
| V11 Business Logic | No | No business logic. |
| V12 Files | Partial | HM manages/backs up dotfiles; stale user dotfiles can shadow managed config (Pitfall 4) — operational, not an exploit. |
| V13 API | No | No API. |
| V14 Config | Yes | Entire phase is configuration hardened by evaluation-time typing and pinned inputs. |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Secret/credential leakage into world-readable `/nix/store` | Information Disclosure | No secrets in Phase 2; sign-off on git signing disabled; secrets deferred (Phase 5, sops-nix). |
| Supply-chain drift via floating inputs/packages | Tampering | Single pinned nixpkgs input; flake.lock; no new packages. |
| Arbitrary code execution via runtime plugin download | Elevation/Tampering | **No plugins**; `programs.vim.plugins = lib.mkForce []`; tmux plugins deferred. |
| Shell rc injection / PATH hijack | Tampering | Only declarative, literal strings; no `eval` of external input; no PATH manipulation beyond HM defaults (D-08). |
| Deprecation-induced silent behavior change | — | Use canonical options; verify generated files via `nix eval`. |

## Sources

### Primary (HIGH confidence — read/executed this session)
- HM release-26.05 source, `flake.lock` rev `a6631107…`, store `/nix/store/n1sgi5817026lapddn1n9a095falqbhz-source`:
  - `modules/programs/git.nix` — options + `settings`/deprecated aliases + generated `~/.config/git/config`.
  - `modules/programs/tmux.nix` — options/defaults + generated `~/.config/tmux/tmux.conf`.
  - `modules/programs/bash.nix` — rc files + `hm-session-vars.sh` sourcing.
  - `modules/programs/vim.nix` — `packageConfigurable` default `vim-full`, `plugins` default `[vim-sensible]`, `settings` enum, `extraConfig`.
  - `modules/home-environment.nix` — `home.sessionVariables`.
- `nix eval` option introspection: `.#homeConfigurations.razer-blade.options.programs.{git,tmux,bash,vim}.*`.
- Live probe `/tmp/opencode/hm-probe.nix` (throwaway): confirmed plugins force behavior, package names, generated-file keys, warning emission.
- Repo: `flake.nix`, `lib/composer.nix`, `modules/base/default.nix`, `hosts/razer-blade/{default,home}.nix`, `flake.lock`.

### Secondary (MEDIUM — external docs)
- [CITED: https://nix-community.github.io/home-manager/options.xhtml] — HM option reference (cross-checked against pinned source).
- [CITED: https://man7.org/linux/man-pages/man1/tmux.1.html] — tmux config file search order (`~/.tmux.conf` before `$XDG_CONFIG_HOME/tmux/tmux.conf`).
- [CITED: https://git-scm.com/docs/git-config#FILES] — git config precedence (`$XDG_CONFIG_HOME/git/config` then `~/.gitconfig`).
- Repo: `.planning/STACK.md`, `.planning/REQUIREMENTS.md`, `02-CONTEXT.md`.

### Tertiary (LOW — do not use for option names/types)
- General tutorials — not used; superseded by pinned-source verification.

## Metadata

**Confidence breakdown:**
- Option names/types/defaults: **HIGH** — read from the exact pinned HM revision and confirmed with live eval of the composed config.
- Package mapping (plain vim vs vim-full; no-plugin force): **HIGH** — empirically observed.
- Migration pitfalls (dotfile shadowing): **MEDIUM** — documented behavior + citations; depends on the host's current dotfiles.
- Git identity placeholder acceptability: **MEDIUM** — permitted by CONTEXT discretion, pending user confirmation.

**Research date:** 2026-10-08
**Valid until:** HM/nixpkgs pin change (i.e. until `nix flake update`). Re-verify option names if Home Manager is updated, since 26.05 already carries git deprecation renames.


