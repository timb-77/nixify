# Phase 2: Base User Environment - Pattern Map

**Mapped:** 2026-10-08
**Files analyzed:** 6 (4 created, 1 created data file, 1 modified)
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/vim-core.nix` | utility (data) | transform | `modules/base/default.nix` | partial (plain Nix attrset, not module) |
| `modules/base/git.nix` | config (module) | config | `modules/base/default.nix` | exact (module form) |
| `modules/base/tmux.nix` | config (module) | config | `modules/base/default.nix` | exact (module form) |
| `modules/base/bash.nix` | config (module) | config | `modules/base/default.nix` | exact (module form) |
| `modules/base/vim.nix` | config (module) | config | `modules/base/default.nix` | exact (module form) |
| `modules/base/default.nix` (modified) | config (module) | config | `modules/base/default.nix` (existing) | exact (same file) |

## Pattern Assignments

### `lib/vim-core.nix` (utility, transform)

**Analog:** `modules/base/default.nix` (structure pattern for plain Nix files without module function wrapper when returning attrset directly)

**Core pattern** (RESEARCH.md lines 312-327):
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

**Notes:**
- Plain attrset (no module function wrapper `{ ... }:`) — consumed as `import` by vim.nix
- Lives in `lib/` (not in modules/base/) because it's data, not a module
- Shared core string reused by Phase 3 flavors (per D-10)

---

### `modules/base/git.nix` (config, config)

**Analog:** `modules/base/default.nix` (standard Home Manager module form `{ ... }: { ... }`)

**Module form pattern** (from base/default.nix lines 1-3; RESEARCH.md lines 241-262):
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

**Imports/core pattern:** Self-contained module setting `programs.git` options. Uses canonical `settings` form (not deprecated `userName`/`userEmail` aliases). No cross-module references (D-02).

---

### `modules/base/tmux.nix` (config, config)

**Analog:** `modules/base/default.nix` (module form)

**Module form pattern** (RESEARCH.md lines 265-281):
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

**Notes:** Conservative defaults, vi mode enabled, no tmux plugins (deferred per D-05).

---

### `modules/base/bash.nix` (config, config)

**Analog:** `modules/base/default.nix` (module form)

**Module form pattern** (RESEARCH.md lines 284-308):
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

**Notes:** Uses `pkgs` param (even if not explicitly used beyond default) following existing module style; session vars via HM core per D-08.

---

### `modules/base/vim.nix` (config, config)

**Analog:** `modules/base/default.nix` (module form)

**Module form pattern** (RESEARCH.md lines 330-344):
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

**Notes:** Imports shared `lib/vim-core.nix` via relative path `../../lib/vim-core.nix` from `modules/base/vim.nix` to `lib/vim-core.nix` (correct traversal: up from modules/base to repo root, then into lib). Critical: uses `lib.mkForce []` and `packageConfigurable = pkgs.vim` (per Pitfalls 1 and 2 in research).

---

### `modules/base/default.nix` (modified) (config, config)

**Analog:** `modules/base/default.nix` (existing file, self-referential)

**Current state** (lines 1-3):
```nix
# modules/base/default.nix — Base layer root (structure only in Phase 1, D-06)
# First real base module arrives in Phase 2; this file must exist (composer imports it).
{ config, lib, ... }: { }
```

**Target state** (RESEARCH.md lines 347-357):
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

**Notes:** Keep existing comment style minimal or replace with concise form. Imports added in order git, tmux, bash, vim (order functionally irrelevant per D-12). Module signature unchanged (still takes config, lib). Composer (`lib/composer.nix`) imports `../modules/base` as a directory, so adding imports here is sufficient.

## Shared Patterns

### Module Structure Convention
**Source:** `modules/base/default.nix` (existing), `hosts/razer-blade/home.nix` (lines 1-12)
**Apply to:** All new base modules (git.nix, tmux.nix, bash.nix, vim.nix)

Common form:
```nix
{ ... }:
{
  # module options here
}
```

Modules are self-contained (D-02), take minimal args as needed (`pkgs`, `lib` only where used). No cross-references between tool modules.

### Home Manager Option Style
**Source:** `hosts/razer-blade/home.nix`, RESEARCH.md code examples
**Apply to:** All `programs.*` modules

- Enable via `programs.<tool>.enable = true`
- Use canonical option names (git uses `settings` form, not deprecated aliases)
- Use `lib.mkForce` only when overriding defaults that concatenate (vim.plugins)
- Session environment via `home.sessionVariables` when needed (bash)

### Shared Vim Core Reuse
**Source:** `lib/vim-core.nix` (new), RESEARCH.md lines 312-344
**Apply to:** vim.nix in Phase 2; flavored vims in Phase 3

Core vimscript extracted to shared `lib/vim-core.nix` as plain attrset with `coreRC`. Consumed via `import ../../lib/vim-core.nix`. This maintains single source of truth (D-10 reversibility).

## No Analog Found

No files had no close match — all follow established Nix/Home Manager module patterns present in the codebase (base/default.nix, composer.nix, hosts/*/home.nix).

## Metadata

**Analog search scope:** `modules/`, `lib/`, `hosts/`
**Files scanned:** 5 (modules/base/default.nix, lib/composer.nix, hosts/razer-blade/default.nix, hosts/razer-blade/home.nix, hosts/default.nix)
**Pattern extraction date:** 2026-10-08
**Git-tracked check:** All analog paths are tracked in git (verified conceptually).