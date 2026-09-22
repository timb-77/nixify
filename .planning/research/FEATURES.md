# Feature Research

**Domain:** Multi-host Nix flake configuration (NixOS + standalone Home Manager) — personal dotfiles-as-flake
**Researched:** 2026-09-22
**Confidence:** MEDIUM

## Executive Summary

The ecosystem around personal nix-config flakes has converged on a small, repeatable feature set: a flake entrypoint with a `mkHost` helper, `hosts/<name>/` per-machine directories, a shared `home/` module tree imported identically by NixOS and standalone Home Manager, and a reusable `modules/` directory. Every mature repo ships the same base programs (git, a managed shell, tmux, one editor, CLI essentials) plus sops-nix or agenix for secrets and a `nix flake check`-gated build. The differentiators in this space are organizational (roles/profiles layering, headless-safe bases) and operational (bootstrap scripts, rebuild command wrappers), not exotic features.

For nixify, the requirements (NIX-01..NIX-18) align almost exactly with ecosystem table stakes — the one genuinely distinctive feature is **three side-by-side vim flavors sharing one core** with nix-store-pinned plugins and nix-store debug adapters, which no surveyed repo does (they all pick a single editor). The other differentiator is the **strict "identical user config across host kinds by construction"** promise (NIX-02), achievable by importing one `home.nix` from both the NixOS module path and the standalone builder path.

The most consequential research finding is operational, not architectural: **new-host secrets bootstrap has a chicken-and-egg problem** (age key must exist before sops-nix can decrypt; the key only exists after first activation). The ecosystem's proven pattern is a two-pass onboarding (provision with placeholder secrets → first boot generates host key → register in `.sops.yaml` → `sops updatekeys` → rebuild). This directly shapes the bootstrap feature (NIX-17) and must be a planned step, not an afterthought.

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Layered config (Base → Roles → Host) with clear precedence | Every mature multi-host repo (EmergentMind, zenware, zekzekus, moons-14) organizes this way; EmergentMind states it as a hard rule: *core* on all hosts, *optional* opt-in, host overrides last | MEDIUM | Maps to NIX-03. Precedence: `home/` shared core < roles/profiles < `hosts/<name>/`. |
| One-dir-per-host + registry line to add a machine | Universal pattern (treffynnon auto-discovers `hosts/`, others keep a `hosts/default.nix` registry); users expect adding a host to be mechanical | LOW | Maps to NIX-04. Keep the `hosts/<name>/` = `{default.nix, home.nix, secrets.yaml}` shape. |
| Managed git + tmux + shell via HM programs modules | Present in literally every surveyed repo; `programs.git.enable+settings`, `programs.tmux.enable+extraConfig`, `programs.bash.enable` | LOW | Maps to NIX-05/NIX-15. `programs.bash.enable` is also the mechanism that sources `hm-session-vars.sh` (required for profiles/env on non-NixOS). |
| Shared user config across host kinds from one module tree | Ecosystem standard: write HM modules once, import from both NixOS (`home-manager.users.<name>`) and standalone (`homeManagerConfiguration`) | MEDIUM | Maps to NIX-02. Concern: keep the shared tree free of NixOS-only and standalone-only options or guard them (`isNixOS` specialArg). |
| Secrets: sops-nix with per-host age keys, encrypted files in repo | sops-nix is the dominant choice for repo-committable encrypted secrets among surveyed repos (EmergentMind, moons-14, zenware, hyprnixmacs, frankper, HALLway); the sops-nix README documents the `.sops.yaml` anchor pattern | MEDIUM | Maps to NIX-08/NIX-09. Structure: `.sops.yaml` + per-host `hosts/<name>/secrets.yaml`, admin/recovery key in every rule. |
| `nix flake check` builds all host closures + HM configs + fmt gate | Repos treat checkable/evaluable flakes as baseline hygiene; several ship CI checks (zekzekus checks.nix, moons-14 treefmt+pre-commit) | MEDIUM | Maps to NIX-10/NIX-11. HM configs are NOT auto-checked — wire explicit `checks` (see STACK.md skeleton). |
| Single pinned nixpkgs input, HM follows same nixpkgs | Consensus pattern for personal repos; multiple inputs only when cherry-picking unstable (cinque.dk) — deliberate trade | LOW | Maps to NIX-12. ⚠️ STACK.md finding: pin must be `nixos-26.05` (25.05 is EOL). |
| Per-host secrets file colocated in host dir | frankper (`hosts/<name>/secrets.yaml`), HALLway, nicolkrit999 all colocate; path_regex in `.sops.yaml` maps host dir → host key | LOW | Simplest rule shape: `path_regex: hosts/([^/]+)/secrets\.yaml$` per host. |
| Bootstrap path documented + scripted for both host kinds | Repos ship `scripts/setup.sh` (treffynnon, MaxWolf-01) or `nix run` flake apps (ahmedelgabri); fresh-machine provisioning is the point of the whole repo class | MEDIUM | Maps to NIX-17. See Bootstrap feature below. |
| XDG/home file management for configs without dedicated modules | `xdg.configFile` / `home.file` used everywhere for the long tail of dotfiles | LOW | Needed for vim extra configs, `.gdbinit`, per-project `.vimspector.json` (NIX-14). |
| Standalone hosts set `targets.genericLinux.enable = true` | Non-negotiable on non-NixOS (NixOS wiki) — fixes XDG_DATA_DIRS so nix-installed GUI apps/desktop files resolve | LOW | First host (Pop!_OS, NIX-18) depends on it. |

### Differentiators (Competitive Advantage)

For a single-user personal project, "differentiation" = features this repo has that typical repos or the user's *previous manual setup* lack. Align with the Core Value (one source of truth, reproducible, provisionable <1h).

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Three side-by-side vim flavors (`vim`, `vim-cpp`, `vim-py`) sharing one core | No surveyed repo ships multiple *vim* flavors (they pick one editor); matches the user's existing vim-cpp/vim-py workflow (NIX-05/06/07). Distinct executables via `vim-full.customize { name = ... }`; one `coreRC` string + one base plugin list = single source of truth | MEDIUM | The `name` attr is the official mechanism (nixpkgs vim docs). Customized vim ignores `~/.vimrc` → all config lives in `customRC`. |
| Working vimspector debugging (C++ + Python) with zero runtime downloads | Ecosystem treats vimspector as the "vim as IDE" debugger, but almost everyone runs `:VimspectorInstall` (runtime fetch) — this repo pins adapters in the nix store (CodeLLDB + debugpy) and defines `g:vimspector_adapters`, satisfying both NIX-14 and the no-runtime-fetch constraint | HIGH | Requires `vim-full` (huge build + python3). Per-project `.vimspector.json` declaratively shipped via `home.file`. |
| Identical user config across NixOS and standalone *by construction* | Same `home.nix` evaluated through both paths (NIX-02) — stronger guarantee than "keep them in sync", which is what most dual-host repos actually do | MEDIUM | Shared HM tree + per-`system`-guarded options. Hidden trap: NixOS-only modules (e.g. `xcursor`-level system bits) must not leak into the shared tree. |
| Add-host in one directory + one registry line, covered by checks | Mechanical host addition whose failure mode is caught by `nix flake check` (NIX-04 + NIX-10 combined) | LOW | Registry in `hosts/default.nix`; new host also needs `sops updatekeys`. |
| <1 hour, <10 manual steps bootstrap (NIX-17) | Core value promise made concrete; scripted two-pass new-host onboarding (see Dependencies) | MEDIUM | `nix run home-manager/release-26.05 -- switch --flake .#<host>` avoids persistent HM install. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Runtime plugin fetching (vim-plug `plug.*`, `:VimspectorInstall`, coc extension install) | Familiar plugin-manager UX | Violates NIX-06 constraint (no runtime fetching); breaks offline builds, `nix flake check`, CI; version drift vs pinned nixpkgs | `pkgs.vimPlugins` start/opt lists (native vim packages) + nix-store adapter definitions |
| Remote/fleet deployment (deploy-rs, colmena, nixops, nixinate) | "Deploy to all machines at once" appeal | Extra inputs, secrets handling, and failure modes for a single user; already declared out of scope | `nixos-rebuild switch --flake .#host` / `home-manager switch --flake .#host` per machine |
| disko / impermanence / secure boot | Reproducible disk layouts are seductive in the ecosystem (moons-14, hyprnixmacs, EmergentMind all use disko) | Root-only, per-machine hardware risk, install-time complexity; out of scope per PROJECT.md | Explore only if a future NixOS host needs full disk automation; keep `hardware.nix` conventional |
| Full DE theming (stylix, GTK/Qt theming) | Ecosystem repos look impressive with unified theming | Massive package/closure surface; not required for identical *experience*; out of scope | Just installing GUI apps (NIX-16) via `home.packages` + `xdg.desktopEntries` |
| nix-ld on non-NixOS hosts | Make arbitrary nix-built binaries run on foreign distros | Needs OS-level loader symlinks (root/systemd); most real GUI apps ship FHS-wrapped in nixpkgs | Defer until a specific app fails; revisit per-app with `steam-run`-style wrappers |
| Private secrets repo as flake input (EmergentMind pattern) | Keeps the public repo free of encrypted blobs | Adds a mandatory private clone + `inputs` update on every machine before rebuild — extra bootstrap steps that fight NIX-17 (<10 steps) | Commit encrypted `secrets.yaml` directly (CI/forks see only ciphertext; sops-nix README confirms this is safe) |
| Multi-nixpkgs inputs / per-host unstable channel (cig0 channelMap, cinque.dk unstable overlay) | Access to newer packages | Breaks single-input constraint (NIX-12) and the stability decision; two `pkgs` sets to reason about | Stay on one stable nixpkgs; evaluate pin bumps on your own cadence |
| Custom module framework (moons-14 `features` + `profiles` layering, cig0 "modulon" dynamic loading) | DRY abstraction of host composition | Over-engineering for a 1-2 host single-user repo; indirection makes every new module cost more than it saves | Plain `imports` + a `roles/` dir (Base → Roles → Host only, NIX-03) |
| Imperative state (channels, `nix-env -i`, ad-hoc `home-manager` channel install) | Rapid ad-hoc package installs | Exactly what the flakes-only + reproducible constraints forbid | Flake inputs + lock; add packages to `home.packages` and rebuild |

## Feature Dependencies

```
[vim flavors (vim / vim-cpp / vim-py)]  ──requires──> [vim-full.customize]
    └──requires──> [pkgs.vimPlugins]  ──requires──> [single pinned nixpkgs (26.05)]

[vimspector debugging (C++)]  ──requires──> [vim-cpp flavor (vim-full python3)]
[vimspector debugging (Py)]  ──requires──> [vim-py flavor (vim-full python3)]
[vimspector adapters in store]  ──requires──> [CodeLLDB + debugpy pkgs]  ──requires──> [single nixpkgs]

[identical user config (NIX-02)]  ──requires──> [shared home/ module tree]
[shared home/ module tree]  ──requires──> [dual-eval path (NixOS module + standalone builder)]

[secrets decryption at activation]  ──requires──> [age key on target host]
[age key on target host]  ──requires──> [registration in .sops.yaml + sops updatekeys]
[first-activation age key]  ──conflicts──> [secrets needed at first activation]  (two-pass onboarding)

[bootstrap <1h (NIX-17)]  ──requires──> [Nix installed on target]
[Nix installed on target]  ──requires──> [official/determinate installer (non-NixOS) | nixos-install (NixOS)]
[bootstrap <1h]  ──enhances──> [two-pass secrets onboarding script]

[checks (NIX-10)]  ──requires──> [formatter wired (NIX-11)]
[checks]  ──enhances──> [add-host workflow (NIX-04)]  (broken host addition fails check)

[GUI apps on standalone (NIX-16)]  ──requires──> [targets.genericLinux.enable]  ──requires──> [xdg.desktopEntries/mimeApps]
```

### Dependency Notes

- **[vim flavors] requires [vim-full.customize] + [pkgs.vimPlugins]:** the only mechanism producing multiple side-by-side vim executables with disjoint plugin sets from the single nixpkgs input (nixpkgs vim docs; HM `programs.vim` supports one vim only). All three flavors must derive from `vim-full` because vimspector needs the huge+python3 build (NIX-14) and the plain `vim` package disables python3.
- **[vimspector] requires flavors, not the plain vim:** even the *core-only* `vim` flavor (NIX-07) could be plain vim, but shipping all three from `vim-full` keeps the closure consistent; vimspector is only wired into vim-cpp/vim-py.
- **[secrets] two-pass onboarding (critical):** on a fresh machine `generateKey = true` creates `~/.config/sops/age/keys.txt` during first activation — but secrets encrypted for a key that does not yet exist cannot be decrypted on that first pass. Ecosystem solutions: (a) first boot with a placeholder `secrets.yaml` or `enableSops` off (frankper), then extract the host's new public key, add to `.sops.yaml`, `sops updatekeys`, commit, rebuild; or (b) derive host keys from existing SSH host keys (`ssh-to-age`) on NixOS, so registration can happen *before* first rebuild (nicolkrit999, HALLway). Plan the chosen sequence explicitly in the bootstrap script so NIX-17 counts it as one documented step.
- **[checks] enhances [add-host]:** because `checks` builds `self.nixosConfigurations.*.config.system.build.toplevel` and HM `activationPackage` per system, a registry/host-dir mistake fails `nix flake check` before any machine is touched — this is what makes "add host = 1 dir + 1 line" safe.
- **[GUI apps] requires [targets.genericLinux]:** GNOME/Pop!_OS "Show Applications" may not surface nix-installed apps without XDG_DATA_DIRS export (home-manager#1439); `targets.genericLinux` handles login shells, desktop-session export may need one documented manual step (STACK.md).

## MVP Definition

v1 == the Active requirement set (NIX-01..NIX-18) on the first host. The core value to validate: *fresh Pop!_OS machine → working identical environment in under an hour, declaratively, without manual setup.*

### Launch With (v1)

- [ ] **Layered Base → Roles → Host structure** (NIX-03) — flake skeleton with `hosts/`, `modules/`, `home/`; first host `hosts/pop/` (NIX-18). Everything else hangs off this.
- [ ] **Base tools on all machines** (NIX-05/07/15): `programs.git`, `programs.tmux`, `programs.bash`, plain `vim` (core only — the fate of the other two flavors is gated on vim-cpp/py working).
- [ ] **vim-cpp + vim-py side-by-side with shared core** (NIX-06) — two `vim-full.customize` flavors from one `coreRC` + one base plugin list; plugins pinned via `pkgs.vimPlugins`; proves the "one source of truth" for editor config.
- [ ] **Working vimspector for C++ and Python** (NIX-14) — CodeLLDB + debugpy adapters from the nix store, `g:vimspector_adapters`, no `:VimspectorInstall`; a `.vimspector.json` sample for each language shipped via `home.file`.
- [ ] **sops-nix user-level secrets on standalone HM** (NIX-08/09) — per-host `secrets.yaml`, `.sops.yaml` anchors (admin + host key), decrypted only on target. *First host only needs the HM module path; the NixOS system module can wait.*
- [ ] **Bootstrap script** (NIX-17) — install Nix → `nix run home-manager/release-26.05 -- switch --flake .#pop` → two-pass secrets if secrets exist at first boot; documented <10 steps, timed format: first host's bootstrap run proves the promise.
- [ ] **`nix flake check` + nixfmt gate** (NIX-10/11) — host closure + HM activation package + fmt check wired as `checks`; run locally (no CI, per scope).

### Add After Validation (v1.x)

- [ ] **NixOS host joins the flake** — exercises the NixOS path of the same `home.nix` (validates NIX-01/02 for real; standalone-only so far). Trigger: user actually installs a NixOS machine or VM.
- [ ] **System-level sops secrets** (`sops-nix.nixosModules.sops`, `/run/secrets`) — only needed when a NixOS *service* (e.g. WLAN, a daemon) needs a secret at boot; user scope doesn't. Trigger: first NixOS host with a boot-time secret.
- [ ] **aarch64-linux host** — flake already lists both systems (NIX-13); trigger: Raspberry Pi or ARM laptop entered as a host.
- [ ] **GUI apps via Nix on non-NixOS** (NIX-16) — install a first critical GUI app through `home.packages` + fix desktop-file surfacing; validates the XDG story. Trigger: one app the user actually uses daily.

### Future Consideration (v2+)

- [ ] nixos-anywhere for unattended/remote NixOS installs — requires disko disk config, currently out of scope. Trigger: a remote/headless NixOS machine appears.
- [ ] More vim flavors or editor consolidation — the three-flavor scheme's maintenance cost vs. value; trigger: user's language set changes.
- [ ] `flake-parts` migration — only if module count/`perSystem` boilerplate grows past comfort (STACK: ~50+ modules). Non-goal now.
- [ ] Roles beyond base (e.g. `roles/dev`, `roles/media`) — Base → Roles layering exists now; concrete roles only when a second machine needs a *different* role. Anti-pattern risk: premature role abstraction with one host.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Layered structure + host registry (NIX-03/04) | HIGH | LOW | P1 |
| Base tools: git, tmux, bash (NIX-05/15) | HIGH | LOW | P1 |
| Three vim flavors w/ shared core (NIX-06/07) | HIGH | MEDIUM | P1 |
| vimspector C++/Python debugging (NIX-14) | HIGH | HIGH | P1 |
| sops-nix per-host secrets (NIX-08/09) | HIGH | MEDIUM | P1 |
| Bootstrap script + two-pass secrets (NIX-17) | HIGH | MEDIUM | P1 |
| checks + fmt gate (NIX-10/11) | MEDIUM | LOW | P1 |
| Single nixpkgs input, follows (NIX-12) | HIGH | LOW | P1 (constraint) |
| Identical config by construction (NIX-02) | HIGH | MEDIUM | P1 (via shared tree) |
| x86_64 + aarch64 systems list (NIX-13) | LOW | LOW | P2 (write now, test later) |
| System-level sops secrets on NixOS | MEDIUM | MEDIUM | P2 (deferred) |
| GUI apps via Nix on non-NixOS (NIX-16) | MEDIUM | MEDIUM | P2 |
| More hosts (NixOS host #2) | HIGH | MEDIUM | P2 (validates NIX-01) |
| nixos-anywhere / disko | LOW | HIGH | P3 |
| flake-parts migration | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch (all Active requirements on first host)
- P2: Should have, add when possible (validated by second machine)
- P3: Nice to have, future consideration

## Competitor Feature Analysis

Reference repos (the closest "competitors" a personal dotfiles flake has — they are also the source material for expectations):

| Feature | Misterio77 nix-starter-configs | EmergentMind/nix-config | zekzekus/dotfiles | moons-14/dotfiles | Our Approach (nixify) |
|---------|--------------|--------------|--------------|--------------|--------------|
| Both NixOS + standalone HM | Yes (starter template for exactly this) | NixOS + HM module only | Yes (nixos, darwin, generic-linux builder) | NixOS + HM module | Yes — same `home.nix` through both eval paths (NIX-02) |
| Host organization | `hosts/<name>` | `hosts/<name>` + `hosts/common/{core,optional}` (hard core rule) | `nix/hosts/<name>` + `profiles = [...]` + `platforms/` | `hosts/<name>` + `profiles/{interfaces,platforms,workloads}` | `hosts/<name>` + `roles/` (Base → Roles → Host, NIX-03) |
| Editor | Neovim (nixvim) | Neovim | Neovim (Lua, symlinked) | Neovim (nixvim) | **vim + vim-cpp + vim-py** (three `vim-full.customize` flavors) |
| Debugging | n/a | n/a | n/a | n/a | vimspector, adapters from nix store (NIX-14) |
| Secrets | sops-nix | sops-nix + private `nix-secrets` flake input | 1Password agent (mac-focused) | sops-nix + age + YubiKey | sops-nix, per-host `secrets.yaml` + admin key (NIX-08) |
| Check/CI | — | checks | checks.nix (fmt, deadnix, statix) | treefmt + pre-commit | `checks` for all host closures + fmt (NIX-10/11) |
| Bootstrap | — | devshell for manual bootstrapping | `nix run` apps + scripts/ | — | `scripts/setup.sh` + two-pass secrets (NIX-17) |
| Disk/impermanence | — | disko + impermanence | — | disko | Out of scope (PROJECT.md) |

**Takeaway:** nixify is *simpler* than every surveyed repo on purpose (single user, no disk automation, no DE theming, no CI) while being *more rigorous* on the two axes the user cares about: multi-flavor vim + no-runtime-fetch, and truly identical user config across host kinds.

## Sources

- Misterio77/nix-starter-configs (GitHub) — the canonical starter for NixOS+HM flakes. [MEDIUM]
- EmergentMind/nix-config README — hosts/common/{core,optional} hard rule, private nix-secrets repo pattern. [MEDIUM]
- zekzekus/dotfiles README — headless-safe base, profiles as role bundles, `mkHomeConfiguration` with `generic-linux` target. [MEDIUM]
- moons-14/dotfiles README — hosts/modules/{applications,system,features}/profiles layout, sops-nix + age. [MEDIUM]
- ratachapada/nix, ahmedelgabri/dotfiles, usrrname/dotfiles, rasmus-kirk/nix-config, ratachapada/nix (repo READMEs) — corroborating layouts and base feature sets. [MEDIUM]
- cinque.dk "A modular NixOS flake for four hosts" (Jhonata Poma-Hansen) — profile aggregation vs 30-line import anti-pattern, sops secrets via `/run/secrets`, Justfile wrappers. [MEDIUM]
- NixOS wiki — Vim (customize), Home Manager ("programs.bash.enable = true" as session-vars sourcing mechanism, `targets.genericLinux`, migration via `bashrcExtra`). [HIGH for wiki-documented claims]
- nixpkgs `doc/languages-frameworks/vim.section.md` — `vim-full.customize`, `name` for side-by-side executables, native vim packages vs vim-plug, `:packadd` opt pattern. [HIGH]
- preservim/tagbar, lpeters999/vim-elysium, rapphil/vim-python-ide, skywind3000/gutentags_plus — the canonical C++/Python vim plugin set (tagbar + gutentags + Universal Ctags; ALE/jedi-vim/pep8-indent for Python; vimspector for debugging). [MEDIUM]
- nix-community/nixos-anywhere README + quickstart — remote/unattended NixOS install (flagged as out of scope, future consideration). [MEDIUM]
- treffynnon/nix-setup, MaxWolf-01/dotfiles, ELD/nix-system — `setup.sh` bootstrap scripts, `nix run home-manager -- switch --flake`, `nixos-install --flake`. [MEDIUM]
- Mic92/sops-nix README — `.sops.yaml` anchors/key_groups, `updatekeys`, `generateKey`, `sshKeyPaths`, HM module paths, key_groups-list syntax pitfall. [HIGH for README claims]
- frankper "the-one-nix" settings/sops docs — dual-key (age + SSH) registration, `just sec-onboard-host` workflow, two-pass onboarding, validation checks. [MEDIUM]
- MarkusBitterman/HALLway docs/secrets.md — admin-key-cryptography model, rekey-from-workstation, per-host decryption isolation, `rotate-key` conventions. [MEDIUM]
- nicolkrit999 nixOS sops-guide — path_regex → host key mapping, `sops updatekeys` after moving/adding files, new-PC onboarding scenarios. [MEDIUM]
- unmovedcentre.com NixOS Secrets Management; pvv-nixos-config secret-management.md — SSH-host-key-derived age keys, dev/admin key as escape hatch. [MEDIUM]
- Home Manager manual + option docs (programs/bash.nix, programs/tmux.nix module sources) — exact option shapes for base programs. [HIGH]

**Confidence:** feature-set claims MEDIUM (heavy multi-repo concordance + official docs); vim flavor mechanism HIGH (nixpkgs docs); secrets workflow MEDIUM (README + 5 independent guides converging on the same shapes); bootstrap patterns MEDIUM (multi-source, varies by personal taste). LOW-confidence items called out inline.

**What might I have missed:** vim-plugin *versions* drift per nixpkgs bump (validate once per upgrade, cf. STACK.md); coc.nvim's Node runtime requirement vs. clangd direct integration for C++ LSP (worth an explicit choice in the vim phase); whether the user's `~/.vimrc` from their current machines needs migration into `coreRC` (the customize mechanism silently ignores `~/.vimrc`).

---
*Feature research for: nixify — multi-host Nix flake (NixOS + standalone Home Manager)*
*Researched: 2026-09-22*