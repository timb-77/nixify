# Stack Research

**Domain:** Nix flake multi-host configuration (NixOS + standalone Home Manager)
**Researched:** 2026-09-22
**Confidence:** MEDIUM (HIGH where marked)

> **Headline finding:** The `nixpkgs 25.05` pin in PROJECT.md is **end-of-life** (EOL 2025-12-31, no security updates since). As of September 2026 the only supported stable is **26.05** ("Yarara", released 2026-05-30, supported to 2026-12-31). This research recommends updating Key Decision NIX-12 to `nixos-26.05` while keeping the single-nixpkgs-input constraint. Everything below assumes 26.05.

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| nixpkgs | `nixos-26.05` (⚠️ not 25.05) | Package set + NixOS module system | Only stable branch still receiving security updates (25.05 EOL 2025-12-31, 25.11 support ended 2026-06-30). Releases: 26.05 = 2026-05-30; next: 26.11. Single input constraint (NIX-12) is the right pattern — just bump the branch. [HIGH] |
| Home Manager | flake input `github:nix-community/home-manager/release-26.05` | User environment; NixOS module **and** standalone | HM releases are branches matching NixOS releases; `release-26.05` pairs with nixpkgs 26.05. Use `home-manager.inputs.nixpkgs.follows = "nixpkgs"` to keep exactly one nixpkgs in the lock. [HIGH] |
| sops-nix | flake input `github:Mic92/sops-nix` (pinned by flake.lock), `inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs"` | Secrets (NIX-08/09) | Only ecosystem tool with **both** a NixOS module (`nixosModules.sops`) **and** a Home Manager module (`homeManagerModules.sops`); age-based; encrypted files are directly committable; can reuse the same shared home module on both host kinds (NIX-09). |
| Nix | 2.29 (already installed) | Flake evaluation | Flakes are stable; 2.29 supports everything used here (`nix flake check`, `--all-systems`, `nix fmt`, `flake follows`). No action. |
| vim-full (`.customize`) | nixpkgs 26.05 (`vim_configurable` is a deprecated alias) | Custom vim flavors (NIX-06/07) | `vim-full.customize { name = "vim-cpp"; ... }` — the `name` attr sets the **executable name**, which is the official mechanism for multiple side-by-side vim flavors with disjoint plugin sets from the same `pkgs.vimPlugins` set. Uses native vim packages (`:help packages`) → zero runtime plugin fetching. [HIGH] |
| pkgs.vimPlugins | nixpkgs 26.05 | Pinned vim plugins (NIX-06) | Generated from `vim-plugin-names`; every plugin pinned at the nixpkgs revision. `vimPlugins.vimspector` confirmed present. |
| nixfmt-rfc-style | nixpkgs 26.05 | Formatter (NIX-11) | RFC 166 standard style; the community default (being enforced in nixpkgs itself). Wire to `nix fmt` + a `checks` entry. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Home Manager `homeManagerConfiguration` | release-26.05 | Standalone configs `homeConfigurations.<name>` | Every non-NixOS host (Pop!_OS first). |
| Home Manager `nixosModules.home-manager` | release-26.05 | HM inside NixOS (`home-manager.users.<name>`) | Every NixOS host; `useGlobalPkgs = true; useUserPackages = true;`. |
| `pkgs.lldb` (bin `lldb-vscode`) | nixpkgs 26.05 | vimspector C++ adapter | Lightweight option; needs `llvm-symbolizer` on PATH — use CodeLLDB if that's fiddly. |
| `pkgs.vscode-extensions.vadimcn.vscode-lldb` | nixpkgs 26.05 | vimspector C++ adapter (CodeLLDB) | Recommended for C++/vimspector: self-contained, upstream's own recommendation for C++. Adapter binary: `${...}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb`. |
| `pkgs.python3Packages.debugpy` | nixpkgs 26.05 | vimspector Python adapter | vimspector's built-in `debugpy` gadget name, pointed at the store path via `g:vimspector_adapters`. |
| `pkgs.age` / `age-keygen` | nixpkgs 26.05 | Host age key generation | `sops.age.generateKey = true` already invokes age-keygen during activation; also needed manually when creating keys for `.sops.yaml`. |
| `pkgs.sops` | nixpkgs 26.05 | Encrypting/secreting files (edit, `updatekeys`) | Developer tooling, not runtime; expose via dev shell or `nix run nixpkgs#sops`. |
| `targets.genericLinux.enable = true` | HM option | Non-NixOS env vars (XDG_DATA_DIRS, etc.) | **Mandatory** on every standalone HM config so GUI apps/desktop files resolve. |
| `xdg.desktopEntries` / `xdg.mimeApps` | HM options | Desktop-file + MIME defaults for nix-installed GUI apps | Any GUI app missing a `.desktop` file or default app association on non-NixOS. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `nix flake check` | Gate: evaluates the flake + builds all `checks` (host closures, HM configs, fmt) | Home Manager configs are **not** auto-checked — wire `checks` explicitly (pattern below). |
| `nix fmt` | Reformat all `.nix` files | Uses `formatter.<system>`; pair with a `--check` gate in `checks`. |
| `nixos-rebuild switch --flake .#<host>` | Apply NixOS hosts | Standard. |
| `home-manager switch --flake .#<host>` | Apply standalone hosts | Also bootstrappable via `nix run home-manager/release-26.05 -- switch --flake .#<host>` (no persistent HM install needed — supports NIX-17). |
| `sops` + `age-keygen` | Edit secrets, rekey after adding hosts | `sops updatekeys <secrets.yaml>` after registering a new host key. |
| `nix flake lock` / `nix flake update nixpkgs home-manager sops-nix` | Pin / refresh inputs | Repo-only pinning; no channels (constraint). |

## Installation

The whole "installation" is the flake skeleton — this *is* the stack. Recommended v1 layout (see ARCHITECTURE research for boundaries):

```text
flake.nix            # inputs, mkHost/mkHome helpers, outputs
lib/                 # helpers: mkHost, mkHome, host list
hosts/<name>/        # per-host entrypoints: default.nix, hardware.nix, home.nix, secrets.yaml
modules/             # NixOS system modules (host-kind shared base, roles)
home/                # Home Manager modules: shared across NixOS + standalone
```

### flake.nix skeleton (multi-host, both host kinds, checks, formatter)

```nix
{
  description = "nixify";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";   # ✔ supported stable (25.05 is EOL)
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";               # single nixpkgs in lock (NIX-12)
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, ... }@inputs:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
      systemConfigs = import ./hosts;   # attrset: name -> { kind = "nixos"|"home"; system; modules? }

      mkNixos = name: cfg: nixpkgs.lib.nixosSystem {
        inherit (cfg) system;
        modules = [
          ./modules                    # base + roles (NIX-03)
          (./hosts + "/${name}/default.nix")
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;    # use system pkgs → no duplicate eval
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs; };
              users.${cfg.user or "tim"} = import (./hosts + "/${name}/home.nix");
            };
          }
        ];
      };

      mkHome = name: cfg: home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsFor cfg.system;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          { targets.genericLinux.enable = true; }   # non-NixOS env (mandatory)
          (import (./hosts + "/${name}/home.nix"))
        ];
      };
    in {
      nixosConfigurations = nixpkgs.lib.mapAttrs
        (name: cfg: mkNixos name cfg)
        (nixpkgs.lib.filterAttrs (name: cfg: cfg.kind == "nixos") systemConfigs);

      homeConfigurations = nixpkgs.lib.mapAttrs
        (name: cfg: mkHome name cfg)
        (nixpkgs.lib.filterAttrs (name: cfg: cfg.kind == "home") systemConfigs);

      formatter = forAllSystems (system: pkgsFor system).nixfmt-rfc-style;

      checks = forAllSystems (system: let
        pkgs = pkgsFor system;
        # build every host closure + HM config for this system
        hostChecks = nixpkgs.lib.mapAttrs' (name: cfg:
          nixpkgs.lib.nameValuePair "host-${name}"
            (if cfg.kind == "nixos"
             then self.nixosConfigurations.${name}.config.system.build.toplevel
             else self.homeConfigurations.${name}.config.system.build.activationPackage))
          (nixpkgs.lib.filterAttrs (name: cfg: cfg.system == system) systemConfigs);
      in hostChecks // {
        # NIX-11: formatting gate
        fmt = pkgs.runCommand "fmt-check" { } ''
          ${pkgs.nixfmt-rfc-style}/bin/nixfmt --check \
            ${toString (builtins.filter (f: builtins.match ".*\.nix" f != null)
                        (builtins.filter builtins.pathExists
                          (map (p: toString p) [ ./flake.nix ./lib ./modules ./home ./hosts ])))}
          touch $out
        '';
      });
    };
}
```

Notes:
- **Adding a host = add `hosts/<name>/` + one line in `hosts/default.nix`** (NIX-04). No flake.nix edits.
- **NixOS module vs standalone share the same `hosts/<name>/home.nix` entry** — both paths evaluate the identical HM module tree, so NIX-02 ("identical user config") holds by construction.
- HM on NixOS uses `useGlobalPkgs=true` so overlays/config live at the system level, not in HM `nixpkgs.*`.

### Vim flavor packaging (NIX-05/06/07)

```nix
# home/vim.nix — shared; builds three packages, one per flavor
{ pkgs, ... }: let
  inherit (pkgs) vim-full;
  inherit (pkgs.vimPlugins) vimspector fugitive vim-airline tagbar ...;

  # shared core: one plugin list + one vimrc body (drives NIX-02 identical UX)
  corePlugins = [ fugitive vim-airline ];           # language-agnostic
  coreRC = ''
    set nocompatible number relativenumber
    syntax on
    filetype plugin indent on
    " ... shared settings ...
  '';
  cppPlugins = corePlugins ++ [ vimspector vim-cpp-enhanced-highlight ];
  pyPlugins   = corePlugins ++ [ vimspector vim-python-pep8-indent ];
in {
  home.packages = [
    (vim-full.customize {                              # NIX-06: vim-cpp flavor
      name = "vim-cpp";
      vimrcConfig.packages.cpp = { start = cppPlugins; opt = [ ]; };
      vimrcConfig.customRC = coreRC + '' " cpp extras: $CXXFLAGS gutentags etc. '';
    })
    (vim-full.customize {                              # NIX-06: vim-py flavor
      name = "vim-py";
      vimrcConfig.packages.py = { start = pyPlugins;  opt = [ ]; };
      vimrcConfig.customRC = coreRC + '' " python extras '';
    })
    (vim-full.customize {                              # NIX-07: plain vim, core only
      name = "vim";
      vimrcConfig.packages.core = { start = corePlugins; opt = [ ]; };
      vimrcConfig.customRC = coreRC;
    })
  ];
}
```

Why this shape:
- `customize.name` produces three distinct executables (`vim`, `vim-cpp`, `vim-py`) → truly side-by-side, each with its **own** hardened plugin set → no shared plugin state (constraint) and no runtime fetching (constraint): plugins come from `pkgs.vimPlugins` at the pinned nixpkgs revision (NIX-06).
- A customized vim **silently ignores `~/.vimrc`** — so all vimrc lives in `customRC`. Good: config is in the flake, not in the home dir. Share the core string (`coreRC`) to keep one source of truth.
- vimspector **requires a "huge" vim build with python3** → flavors must be built from `vim-full`, never the `vim` package (NIX-14).

### vimspector without runtime gadget downloads (NIX-14, constraint)

Default vimspector wants `:VimspectorInstall` / `g:vimspector_install_gadgets` (downloads debug adapters from the internet) — **that is the runtime-fetch anti-pattern**. Instead, define adapters in the vimrc pointing at nix-store binaries:

```vim
" in vimrcConfig.customRC (nix interpolation gives store paths)
let g:vimspector_adapters = {
  \   'CodeLLDB': {
  \     'name': 'codelldb',
  \     'command': [
  \       '${pkgs.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb',
  \       '--port', '${vimspectorPort}'
  \     ],
  \     'port': '${vimspectorPort}',
  \     'configuration': { 'type': 'lldb' }
  \   },
  \   'debugpy': {
  \     'extends': 'debugpy',
  \     'command': [ '${pkgs.python3Packages.debugpy}/bin/debugpy', '--listen', '5678' ]
  \   }
  \ }
let g:vimspector_install_gadgets = []   " never fetch at runtime
```

Alternative: bake `.gadgets.d/*.json` into the plugin package via `vimUtils.buildVimPlugin`/`overrideAttrs` (files must live under `<plugin>/gadgets/linux/.gadgets.d/`). `g:vimspector_adapters` is simpler and keeps everything in the vimrc. Per-project `.vimspector.json` config files stay user-side (declarative in repo via `home.file`).

### sops-nix for both host kinds (NIX-08/09)

```nix
# home/secrets.nix — SHARED by NixOS-HM and standalone (imported from each home entrypoint)
{ inputs, ... }: {
  imports = [ inputs.sops-nix.homeManagerModules.sops ];   # one module, both host kinds
  sops = {
    defaultSopsFile = ./secrets.yaml;                      # per-host file (below)
    age.keyFile = ".config/sops/age/keys.txt";             # string path, relative to $HOME
    age.generateKey = true;                                # creates host key on first activation
    secrets.github_token = { };
    secrets.wlan_password = { };
  };
}
```

- **One age key per host** (NIX-08): `age.generateKey` writes a host key to `~/.config/sops/age/keys.txt` at activation; never in the repo.
- **`.sops.yaml`** at repo root registers recipients per host; public keys committed (e.g. `keys/hosts/<name>.age`), private keys exist only on machines:

```yaml
creation_rules:
  - path_regex: hosts/([^/]+)/secrets\.yaml$
    age: [age1<host-pubkey>, age1<recovery-pubkey>]   # swap per host via regex capture is fine, or list all keys
  - path_regex: .*\.ya?ml$
    age: [age1<recovery-pubkey>]
```

After adding a host: `sops updatekeys hosts/<name>/secrets.yaml`.
- **Critical pitfall (verified in README + community configs):** `sops.age.keyFile` MUST be a **string** like `"/home/tim/.config/sops/age/keys.txt"`. A Nix path literal (e.g. `./keys.txt`) copies the private key into the /nix/store. NIXOS-only: system-level secrets use `sops-nix.nixosModules.sops` with `keyFile = "/etc/sops/age/keys.txt"` (+ optional `sshKeyPaths` from host SSH keys). For v1 (single user, user-level secrets) the HM module alone is sufficient on both kinds — defer the NixOS system module until a service needs a secret at boot.
- Secrets encrypted in repo are CI/store-safe (decrypted only during activation on the target) — satisfies "encrypted in repo, decrypted only on target machine" (NIX-08).

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Plain `flake.nix` + `mkHost`/`genAttrs` | `flake-parts` | When the flake grows many `perSystem` outputs / modules. HM ships `home-manager.flakeModules.home-manager` for that day. Re-evaluate at ~50+ modules or if checks boilerplate hurts. |
| Plain `flake.nix` + `mkHost`/`genAttrs` | `flake-utils` | **Never** — NixOS wiki explicitly discourages it (superseded by flake-parts; same problem it solved, module-system flavored). |
| nixpkgs `nixos-26.05` | `nixpkgs-unstable`/`nixos-unstable` | If you accept rolling drift; violates the stability decision. Keep stable + `nix flake update` on your own cadence. |
| HM `release-26.05` branch | HM `master` | If you need unreleased HM modules; costs stability (constraint). |
| sops-nix | agenix | agenix if you prefer one `.age` file per secret and pure age/SSH-only recipients; sops-nix wins here because it has both NixOS and HM modules and multi-secret YAML — exactly NIX-09. |
| `vim-full.customize` flavors | HM `programs.vim` module | HM `programs.vim` supports only **one** vim; `.customize` is the only clean way to three side-by-side executables. |
| `g:vimspector_adapters` in vimrc | `.gadgets.d/*.json` baked into plugin | Use `.gadgets.d` if you dislike vimrc dicts or must share adapter JSON across editors; both avoid runtime downloads. |
| `pkgs.vscode-extensions.vadimcn.vscode-lldb` (CodeLLDB) | `pkgs.lldb` `lldb-vscode` | lldb-vscode when you already accept LLVM toolchain; CodeLLDB when you want one self-contained adapter (recommended default). |
| NixOS: HM as system module | HM standalone everywhere | On NixOS the module form gives one command (`nixos-rebuild switch`) to update system + user env; standalone `home-manager switch` would be a second command per host (violates NIX-17 spirit). |
| `nixfmt-rfc-style` | alejandra | alejandra if you prefer its zero-config opinionated layout; note it deliberately **diverges** from RFC 166 and is unconfigurable; nixfmt-rfc-style is the emerging standard. |
| `nixfmt-rfc-style` | `nixpkgs-fmt` / `nixfmt-classic` | Legacy/rule-based; classic nixfmt is unmaintained (kept only as `nixfmt-classic`). |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| nixpkgs `nixos-25.05` (PROJECT.md pin) | **EOL 2025-12-31**: no security updates, no binary cache guarantee. Pinning it now ships known-vulnerable packages. | `nixos-26.05` (update Key Decision NIX-12) |
| `vim_configurable` | Deprecated alias of `vim-full` (nixpkgs docs) | `vim-full.customize` |
| vim-plug / `vimrcConfig.packages.<x>.plug.*` | Runtime plugin fetching from GitHub (violates NIX-06 "no runtime fetching"; breaks offline/CI builds) | native vim packages: `start`/`opt` lists from `pkgs.vimPlugins` |
| vimspector `:VimspectorInstall` / `g:vimspector_install_gadgets` | Downloads adapters at runtime from the internet into `~/.vimspector` | adapter definitions pointing at nix-store binaries (pattern above) |
| The plain `vim` package for vimspector flavors | Python3 disabled → vimspector refuses to load | `vim-full`-based flavors |
| `flake-utils` | Officially discouraged (NixOS wiki) | plain helpers or flake-parts |
| channels / `nix-channel` / `nix-env` | Imperative state, conflicts with flakes-only constraint | flake inputs + lock |
| HM `nixpkgs.*` options for overlays when using `useGlobalPkgs` | Flat-out ignored in that mode; confusing eval-time bugs | system-level overlays (`nixpkgs.overlays` on NixOS) |
| `builtins.fetchTarball` for HM/sops-nix | Pre-flake channel-era pattern; not locked | flake inputs with `follows` |
| nix-ld on non-NixOS hosts (v1) | Requires OS-level `/lib/ld-linux...` symlinks (root, systemd interplay); nixpkgs FHS-wrapped packages already cover most GUI apps | Defer; revisit if a specific GUI app needs it (NixOS: `programs.nix-ld.enable`) |
| devenv / devbox / NixOS microVM tooling | This is a *configuration* repo, not a software dev repo | plain flake |

## Stack Patterns by Variant

**If the host is NixOS:**
- Use `nixosConfigurations` + `home-manager.nixosModules.home-manager` (`useGlobalPkgs=true`, `useUserPackages=true`, `extraSpecialArgs`, `users.<name>` = same `home.nix` as standalone).
- System modules in `modules/` (base → roles → host layering, NIX-03); hardware config in `hosts/<name>/hardware.nix`.
- Secrets at system level later via `sops-nix.nixosModules.sops`; v1 user-level secrets via the HM module only.

**If the host is non-NixOS (standalone HM — Pop!_OS first, NIX-18):**
- `homeConfigurations.<name>` via `home-manager.lib.homeManagerConfiguration` with explicit `pkgs = nixpkgs.legacyPackages.${system}` and `extraSpecialArgs`.
- `targets.genericLinux.enable = true` (XDG env, desktop files) — non-negotiable on GNOME/Pop!_OS.
- GUI apps via `home.packages` + `xdg.desktopEntries`/`xdg.mimeApps`. Known caveat: GNOME "Show Applications" may not surface nix-installed apps (home-manager#1439) — fix by exporting `~/.nix-profile/share/applications` through `XDG_DATA_DIRS` (targets.genericLinux does this in login shells; a desktop-session-level export may be needed — one-time manual step per machine, tracked in docs).
- Bootstrap: `nix run home-manager/release-26.05 -- switch --flake .#<host>` — no persistent HM install required (NIX-17).
- Non-NixOS hosts that want bash as login shell already have it (default); HM `programs.bash.enable = true` manages rc (NIX-15).

**If the host is aarch64-linux:**
- Per-host `system` attrset (as in skeleton) keeps it a one-line change; `checks` are per-system so building an aarch64 host's closure on x86_64 doesn't happen accidentally — run `nix flake check` on the machine itself or use `--all-systems` where substitution exists.

**If a new host is added (NIX-04):**
- Create `hosts/<name>/` (default.nix / home.nix / secrets.yaml), add one line to `hosts/default.nix`. Nothing in flake.nix changes. `sops updatekeys` for the new secret file if it has secrets.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| nixpkgs `nixos-26.05` | HM `release-26.05` | HM branches track NixOS releases; matching versions are the supported pairing. [HIGH] |
| HM `release-26.05` | nixpkgs via `home-manager.inputs.nixpkgs.follows` | Removes HM's internal "compat assumption with its own locked nixpkgs" — documented as safe to use carefully; on stable pairs this is the standard pattern. Don't follow `nixpkgs` with HM `master` unless you accept breakage. |
| sops-nix `master` | nixpkgs any (via `follows`) | sops-nix has no release branches; the flake.lock entry pins it. `inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs"` per its README. |
| nixpkgs 26.05 | Nix ≥ 2.24 | Project has Nix 2.29 — no constraint. Older Nix (pre-2.24) was dropped for lock/v1 compat assumptions; irrelevant here. |
| `vim-full` + `vimPlugins.*` | same nixpkgs rev | Both come from the single nixpkgs input; keep them on one branch — mixing unstable plugins with stable vim is not reproducible. |
| `vimPlugins.vimspector` | `vim-full` (huge + python3) | vimspector needs Vim 8.2.4797+ huge build with Python ≥ 3.10 → never the `vim` package. |
| `nixfmt-rfc-style` | nixpkgs ≥ 24.11 | On 25.11+ the plain `nixfmt` attr is the RFC-style formatter and classic is `nixfmt-classic`; pin `nixfmt-rfc-style` explicitly for clarity. |
| `pkgs.vscode-extensions.vadimcn.vscode-lldb` | same nixpkgs rev | `configuration` key `type` in vimspector maps to adapter name `lldb`; validate once per nixpkgs bump (CodeLLDB version moves with nixpkgs). |

## Sources

- NixOS release announcements (nixos.org/blog): 25.05 (2025-05-23), 25.11 (2025-11-30, 7-mo support to 2026-06-30), 26.05 (2026-05-30) — EOL timeline. [HIGH]
- Home Manager manual — NixOS module, Standalone, Flakes chapters; HM README (release branches align with NixOS releases). [HIGH]
- nix-community/home-manager `docs/manual/nix-flakes/*` — `nixpkgs.follows`, `extraSpecialArgs`, `homeManagerConfiguration`, NixOS module options.
- Mic92/sops-nix README + `modules/home-manager/sops.nix` — both modules, `age.keyFile`/`generateKey`/`sshKeyPaths`, keyFile-as-string pitfall, `updatekeys` workflow.
- nixpkgs `doc/languages-frameworks/vim.section.md` — `vim-full.customize`, `vim_configurable` deprecation alias, native packages vs vim-plug. [HIGH]
- NixOS wiki — Vim (customize examples), Flake Utils ("not recommended"), Flake Parts, Home Manager (non-NixOS `targets.genericLinux`), Nix-ld.
- nix manual `nix3-flake-check` / `nix3-fmt` — checked outputs incl. `nixosConfigurations.*.toplevel`, `checks` build semantics, `--all-systems`, `formatter`.
- puremourning/vimspector README — adapter loading order (`.gadgets.json`, `.gadgets.d/*.json`, `g:vimspector_adapters`), `g:vimspector_install_gadgets`, python3/huge-build requirement.
- NixOS Discourse — multi-host `mkHost` pattern (2025-03), HM standalone→module migration, formatters overview (Infinisil/piegames on nixfmt-rfc-style as RFC 166 standard).
- nixpkgs `pkgs/applications/editors/vim/plugins/vim-plugin-names` — `puremourning/vimspector` entry (verified raw, 2026-09). [HIGH]
- nix.dev Flakes concept — `nixpkgs`/`home-manager` follows example; "NixOS 26.05 loads configs from single system.nix entrypoint" (not needed here).
- MyNixOS / official NixOS wiki — HM release branches, package metadata.

**Confidence:** version/EOL claims HIGH (official blogs + release notes); vim/sops/flake patterns MEDIUM (docs + community consensus, some details in the 26.05 docs tree vs older snippets); vimspector adapter-in-Nix end-to-end MEDIUM (pattern assembled from nixvim discourse example + vimspector docs; validate during the vim phase).

---
*Stack research for: nixify — multi-host Nix flake (NixOS + standalone Home Manager)*
*Researched: 2026-09-22*